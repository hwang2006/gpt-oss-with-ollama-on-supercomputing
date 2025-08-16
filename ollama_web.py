import gradio as gr
import requests
from requests.adapters import HTTPAdapter, Retry
import subprocess
import os
import argparse
import json
import html
import time
import re

class OllamaChat:
    def __init__(self, ollama_url="http://localhost:11434"):
        self.base_url = ollama_url
        self.models_dir = os.getenv("OLLAMA_MODELS", "/scratch/qualis/workspace/ollama/models")
        self.session = requests.Session()
        retries = Retry(total=3, backoff_factor=1, status_forcelist=[429, 500, 502, 503, 504])
        self.session.mount("http://", HTTPAdapter(max_retries=retries))

    def get_available_models(self):
        try:
            resp = self.session.get(f"{self.base_url}/api/tags", timeout=30)
            if resp.status_code == 200:
                models = resp.json()
                return [m["name"] for m in models.get("models", [])]
            return []
        except requests.exceptions.RequestException as e:
            print(f"Error fetching models: {e}")
            return []

    def is_model_local(self, model_name):
        return model_name in self.get_available_models()

    def pull_model(self, model_name, progress: gr.Progress):
        if not model_name or not model_name.strip():
            return "Error: Please specify a model name."

        try:
            progress(0, desc=f"Starting pull: {model_name}")
            cmd = ["ollama", "pull", model_name.strip()]
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1
            )

            percent = 0.0
            last_emit = time.time()
            buffer_text = []

            json_progress_re = re.compile(r'"progress"\s*:\s*([0-1](?:\.\d+)?)')
            text_percent_re = re.compile(r'(\d{1,3})%')

            for line in proc.stdout:
                line = line.rstrip()
                buffer_text.append(line)

                m_json = json_progress_re.search(line)
                if m_json:
                    try:
                        p = float(m_json.group(1))
                        percent = max(percent, min(1.0, p))
                    except Exception:
                        pass
                else:
                    m_txt = text_percent_re.search(line)
                    if m_txt:
                        try:
                            p = int(m_txt.group(1)) / 100.0
                            percent = max(percent, min(1.0, p))
                        except Exception:
                            pass

                now = time.time()
                if now - last_emit > 0.1:
                    if percent == 0.0 and (now - last_emit) > 1.0:
                        percent = min(0.1, percent + 0.01)
                    progress(percent, desc=f"Pulling {model_name}… {int(percent*100)}%")
                    last_emit = now

            proc.wait()
            if proc.returncode != 0:
                progress(0, desc=f"Pull failed for {model_name}")
                return "Error pulling model:\n" + "\n".join(buffer_text[-20:])

            progress(1, desc=f"Pull complete: {model_name}")

            # Wait briefly for /api/tags to reflect the new model
            retries = 5
            for _ in range(retries):
                avail = self.get_available_models()
                prefixes = [n.split(":")[0] for n in avail]
                if model_name in avail or model_name.split(":")[0] in prefixes:
                    return f"Successfully pulled model '{model_name}'."
                time.sleep(1)

            return f"Model '{model_name}' pulled but not visible in /api/tags yet."
        except Exception as e:
            progress(0, desc="Pull error")
            return f"Error during model pull: {e}"

    def generate_response_stream(self, message, history, model_name, temperature):
        try:
            url = f"{self.base_url}/api/generate"
            data = {
                "model": model_name.strip(),
                "prompt": message.strip(),
                "stream": True,
                "temperature": float(temperature),
            }
            resp = self.session.post(url, json=data, stream=True, timeout=100)
            if resp.status_code == 200:
                for line in resp.iter_lines():
                    if line:
                        chunk = json.loads(line.decode("utf-8"))
                        decoded = html.unescape(chunk.get("response", ""))
                        if decoded == "<think>":
                            yield "Thinking..."
                        else:
                            yield decoded
            else:
                yield f"Error: Server returned status {resp.status_code} - {resp.text}"
        except requests.exceptions.RequestException as e:
            yield f"Error: {e}"

def wait_for_models(chat, max_wait=60):
    print("⏳ Waiting for Ollama models to become available...")
    elapsed = 0
    while elapsed < max_wait:
        models = chat.get_available_models()
        if models:
            print(f"✅ Models available: {models}")
            return models
        time.sleep(2)
        elapsed += 2
    print("⚠ No models found after waiting, starting with empty list.")
    return []

def preload_model(chat, model_name):
    if not model_name:
        return
    print(f"⏳ Preloading model '{model_name}'...")
    try:
        start = time.time()
        chat.session.post(
            f"{chat.base_url}/api/generate",
            json={"model": model_name, "prompt": "ping", "stream": False},
            timeout=600,
        )
        took = time.time() - start
        print(f"✅ Model '{model_name}' preloaded in {took:.1f}s.")
    except requests.exceptions.RequestException as e:
        print(f"⚠ Preload failed for '{model_name}': {e}")

def create_interface(ollama_url):
    chat = OllamaChat(ollama_url)
    ENV_DEFAULT = os.getenv("DEFAULT_MODEL", None)
    print(f"DEFAULT_MODEL (env) seen by UI: {ENV_DEFAULT}")
    models = wait_for_models(chat)
    if ENV_DEFAULT and ENV_DEFAULT in models:
        default_model = ENV_DEFAULT
    elif models:
        default_model = models[0]
    else:
        default_model = None
    if default_model:
        preload_model(chat, default_model)

    with gr.Blocks(title="Ollama Chat Interface") as iface:
        gr.HTML(
            """
            <style>
              .gradio-container { max-width: 1600px !important; }
              #chat_col .gr-chatbot { max-width: 100% !important; }
              #side_col { min-width: 260px; max-width: 300px; }
            </style>
            """
        )
        gr.Markdown("# Ollama Chat Interface")

        with gr.Row():
            # Wider chat area
            with gr.Column(scale=11, elem_id="chat_col"):
                chatbot = gr.Chatbot(height=520, type="messages")
                message = gr.Textbox(label="Message", placeholder="Type your message here...")
                submit = gr.Button("Send")

            # Narrower side panel
            with gr.Column(scale=1, min_width=260, elem_id="side_col"):
                model_dropdown = gr.Dropdown(
                    choices=models if models else ["No models available"],
                    value=default_model,
                    label="Select Model",
                    interactive=bool(models),
                    elem_id="model_dropdown",
                )
                refresh_button = gr.Button("🔄 Refresh Models")
                model_name_input = gr.Textbox(
                    label="Model Name to Pull from the Ollama site",
                    placeholder="Enter the model name to pull..."
                )
                pull_button = gr.Button("Pull Model")
                pull_status = gr.Textbox(label="Pull Status", interactive=False)
                temperature = gr.Slider(0.0, 1.0, value=0.7, step=0.1, label="Temperature")
                clear = gr.Button("Clear Chat")

        def respond(message, chat_history, model_name, temp):
            if not message.strip():
                return "", chat_history
            new_hist = chat_history + [{"role": "user", "content": message}]
            assistant_msg = ""
            for chunk in chat.generate_response_stream(message, chat_history, model_name, temp):
                assistant_msg += chunk
                yield "", new_hist + [{"role": "assistant", "content": assistant_msg}]

        def update_model_list():
            return chat.get_available_models()

        def refresh_models_action():
            updated = update_model_list()
            if ENV_DEFAULT and ENV_DEFAULT in updated:
                return gr.update(choices=updated, value=ENV_DEFAULT)
            elif updated:
                return gr.update(choices=updated, value=updated[0])
            else:
                return gr.update(choices=["No models available"], value=None)

        def pull_model_action(model_name, progress=gr.Progress(track_tqdm=False)):
            status = chat.pull_model(model_name, progress)
            updated = update_model_list()

            if ENV_DEFAULT and ENV_DEFAULT in updated:
                selected = ENV_DEFAULT
            elif model_name.strip() in updated:
                selected = model_name.strip()
            else:
                selected = updated[0] if updated else None

            # Return: status text, dropdown update, and clear the input textbox
            return (
                status,
                gr.update(choices=updated if updated else ["No models available"], value=selected),
                gr.update(value="")  # clear input box after pull
            )

        submit.click(respond, [message, chatbot, model_dropdown, temperature], [message, chatbot])
        message.submit(respond, [message, chatbot, model_dropdown, temperature], [message, chatbot])
        pull_button.click(
            pull_model_action,
            inputs=[model_name_input],
            outputs=[pull_status, model_dropdown, model_name_input]
        )
        refresh_button.click(refresh_models_action, outputs=[model_dropdown])
        clear.click(lambda: ([], ""), None, [chatbot, message], queue=False)

    return iface

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ollama Web Interface")
    parser.add_argument("--host", type=str, default="0.0.0.0", help="Host to run the server on (default: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=7860, help="Port to run the server on (default: 7860)")
    parser.add_argument("--share", action="store_true", help="Create a public URL (default: False)")
    parser.add_argument("--ollama-url", type=str, default="http://localhost:11434", help="Ollama API URL (default: http://localhost:11434)")
    args = parser.parse_args()
    iface = create_interface(args.ollama_url)
    iface.launch(server_name=args.host, server_port=args.port, share=args.share, show_error=True)

