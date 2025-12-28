#!/usr/bin/env python3
"""
Chatterbox Audiobook Generator - Gradio Web UI
State-of-the-art TTS for audiobook creation with voice cloning
API: https://chatterboxtts.com/docs
"""

import os
import gc
import torch
import gradio as gr
from pathlib import Path
from chatterbox import ChatterboxMultilingualTTS
import torchaudio as ta

# Configuration
OUTPUT_DIR = Path("/app/output")
VOICES_DIR = Path("/app/voices")
CACHE_DIR = Path("/app/cache")
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

# Create directories
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
VOICES_DIR.mkdir(parents=True, exist_ok=True)
CACHE_DIR.mkdir(parents=True, exist_ok=True)

print(f"Device: {DEVICE}")
if torch.cuda.is_available():
    print(f"VRAM Available: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.2f} GB")

print("Loading Chatterbox Multilingual TTS model...")

# Load Chatterbox model
model = ChatterboxMultilingualTTS()


def generate_speech(
    text: str,
    voice_file=None,
    speed: float = 1.0,
) -> tuple:
    """Generate speech from text using Chatterbox TTS."""
    try:
        if not text or len(text.strip()) < 1:
            return None, "Error: Please enter some text."

        print(f"Generating speech for {len(text)} characters...")
        print(f"Speed: {speed}")

        # Generate audio with optional voice cloning
        if voice_file:
            print(f"Using voice file: {voice_file}")
            audio = model.generate(
                text=text,
                audio_prompt_path=voice_file,
                speed=speed,
            )
        else:
            audio = model.generate(
                text=text,
                speed=speed,
            )

        # Save audio file
        output_path = OUTPUT_DIR / f"audiobook_{len(list(OUTPUT_DIR.glob('*.wav')))}.wav"
        ta.save(str(output_path), audio, sample_rate=24000)

        # Cleanup
        gc.collect()
        if torch.cuda.is_available():
            torch.cuda.empty_cache()

        return str(output_path), f"Success! Audio saved to {output_path.name}"

    except Exception as e:
        return None, f"Error: {str(e)}"


def list_output_files():
    """List generated audiobook files."""
    if OUTPUT_DIR.exists():
        files = list(OUTPUT_DIR.glob("*.wav"))
        return [[f.name, f"{f.stat().st_size / 1024 / 1024:.2f} MB"] for f in sorted(files, key=lambda x: x.stat().st_mtime, reverse=True)]
    return []


# Build Gradio Interface
with gr.Blocks(title="Chatterbox Audiobook Generator", theme=gr.themes.Soft()) as demo:
    gr.Markdown("# 🎙️ Chatterbox Audiobook Generator")
    gr.Markdown("State-of-the-art multilingual TTS with voice cloning | [Official Docs](https://chatterboxtts.com/docs)")

    with gr.Tabs():
        # Tab 1: Text to Speech
        with gr.Tab("📖 Text to Speech"):
            text_input = gr.Textbox(
                label="Text to convert",
                placeholder="Enter your text here...",
                lines=10,
            )
            voice_file_input = gr.Audio(
                label="Voice sample (optional - for cloning)",
                type="filepath",
            )
            speed_slider = gr.Slider(
                minimum=0.5,
                maximum=2.0,
                value=1.0,
                step=0.1,
                label="Speed",
            )
            generate_btn = gr.Button("🎵 Generate Audio", variant="primary")
            output_audio = gr.Audio(label="Generated Audio")
            output_message = gr.Textbox(label="Status", interactive=False)

            generate_btn.click(
                fn=generate_speech,
                inputs=[text_input, voice_file_input, speed_slider],
                outputs=[output_audio, output_message],
            )

        # Tab 2: Audiobook Library
        with gr.Tab("📁 Audiobook Library"):
            gr.Markdown("### Generated audiobooks stored in `/app/output`")
            output_files = gr.Dataframe(
                label="Output Files",
                headers=["Filename", "Size"],
                value=list_output_files(),
            )
            refresh_btn = gr.Button("🔄 Refresh")
            refresh_btn.click(fn=lambda: list_output_files(), outputs=output_files)

    gr.Markdown("---")
    gr.Markdown(
        """
        **Tips:**
        - For best voice cloning, upload 8-15 seconds of clear speech
        - Use `[pause:0.5s]` tags in text for pauses
        - Adjust speed to match your preferred narration pace
        - Supports 22+ languages including English, Portuguese, Spanish
        """
    )


if __name__ == "__main__":
    demo.launch(
        server_name="0.0.0.0",
        server_port=7860,
        share=False,
        show_error=True,
    )
