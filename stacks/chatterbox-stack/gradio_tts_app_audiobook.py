#!/usr/bin/env python3
"""
Chatterbox Audiobook Generator - Gradio Web UI
Based on: https://github.com/psdwizzard/chatterbox-Audiobook
State-of-the-art TTS for audiobook creation with voice cloning
"""

import os
import gc
import torch
import gradio as gr
from pathlib import Path
from chatterbox import Chatterbox
import numpy as np
import soundfile as sf

# Configuration
OUTPUT_DIR = Path("/app/output")
VOICES_DIR = Path("/app/voices")
CACHE_DIR = Path("/app/cache")
MODEL_NAME = os.getenv("MODEL_NAME", "resemble-ai/chatterbox-multilingual")
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

# Create directories
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
VOICES_DIR.mkdir(parents=True, exist_ok=True)
CACHE_DIR.mkdir(parents=True, exist_ok=True)

print(f"Loading Chatterbox model: {MODEL_NAME}")
print(f"Device: {DEVICE}")
print(f"VRAM Available: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.2f} GB" if torch.cuda.is_available() else "CPU mode")

# Load Chatterbox model
model = Chatterbox.from_pretrained(MODEL_NAME, device=DEVICE)


def generate_speech(
    text: str,
    voice: str = "default",
    language: str = "auto",
    speed: float = 1.0,
    temperature: float = 0.7,
) -> tuple:
    """Generate speech from text using Chatterbox TTS."""
    try:
        if not text or len(text.strip()) < 1:
            return None, "Error: Please enter some text."

        print(f"Generating speech for {len(text)} characters...")
        print(f"Voice: {voice}, Language: {language}, Speed: {speed}, Temperature: {temperature}")

        # Generate audio
        audio_array = model.generate(
            text=text,
            voice=voice if voice != "default" else None,
            language=language if language != "auto" else None,
            speed=speed,
            temperature=temperature,
        )

        # Save audio file
        output_path = OUTPUT_DIR / f"audiobook_{len(list(OUTPUT_DIR.glob('*.wav')))}.wav"
        sf.write(str(output_path), audio_array, samplerate=24000)

        # Cleanup
        gc.collect()
        if torch.cuda.is_available():
            torch.cuda.empty_cache()

        return str(output_path), f"Success! Audio saved to {output_path.name}"

    except Exception as e:
        return None, f"Error: {str(e)}"


def clone_voice_and_generate(
    text: str,
    voice_file,
    voice_name: str,
    language: str = "auto",
    speed: float = 1.0,
) -> tuple:
    """Clone voice from audio file and generate speech."""
    try:
        if not text or len(text.strip()) < 1:
            return None, "Error: Please enter some text."

        if voice_file is None:
            return None, "Error: Please upload a voice sample file."

        # Save voice sample
        voice_path = VOICES_DIR / f"{voice_name or 'cloned'}.wav"
        import shutil
        shutil.copy(voice_file, voice_path)

        print(f"Cloning voice from: {voice_file}")
        print(f"Generating speech for {len(text)} characters...")

        # Generate audio with voice cloning
        audio_array = model.generate(
            text=text,
            voice=str(voice_path),
            language=language if language != "auto" else None,
            speed=speed,
        )

        # Save audio file
        output_path = OUTPUT_DIR / f"audiobook_cloned_{len(list(OUTPUT_DIR.glob('*.wav')))}.wav"
        sf.write(str(output_path), audio_array, samplerate=24000)

        gc.collect()
        if torch.cuda.is_available():
            torch.cuda.empty_cache()

        return str(output_path), f"Success! Cloned voice saved to {output_path.name}"

    except Exception as e:
        return None, f"Error: {str(e)}"


def list_available_voices():
    """List available voice profiles."""
    voices = ["default"]
    if VOICES_DIR.exists():
        voices.extend([v.stem for v in VOICES_DIR.glob("*.wav")])
    return voices


def list_output_files():
    """List generated audiobook files."""
    if OUTPUT_DIR.exists():
        files = list(OUTPUT_DIR.glob("*.wav"))
        return [[f.name, f"{f.stat().st_size / 1024 / 1024:.2f} MB"] for f in sorted(files, key=lambda x: x.stat().st_mtime, reverse=True)]
    return []


# Build Gradio Interface
with gr.Blocks(title="Chatterbox Audiobook Generator", theme=gr.themes.Soft()) as demo:
    gr.Markdown("# 🎙️ Chatterbox Audiobook Generator")
    gr.Markdown("State-of-the-art multilingual TTS with voice cloning | Based on [resemble-ai/chatterbox](https://github.com/resemble-ai/chatterbox)")

    with gr.Tabs():
        # Tab 1: Basic Text-to-Speech
        with gr.Tab("📖 Text to Speech"):
            with gr.Row():
                with gr.Column(scale=2):
                    text_input = gr.Textbox(
                        label="Text to convert",
                        placeholder="Enter your text here...",
                        lines=10,
                    )
                with gr.Column(scale=1):
                    voice_dropdown = gr.Dropdown(
                        choices=list_available_voices(),
                        value="default",
                        label="Voice",
                    )
                    language_dropdown = gr.Dropdown(
                        choices=[
                            "auto",
                            "en", "pt", "es", "fr", "de", "it", "ja", "ko", "zh",
                            "ru", "nl", "pl", "tr", "ar", "hi", "sv", "no", "da",
                            "fi", "el", "cs", "uk", "vi"
                        ],
                        value="auto",
                        label="Language (auto = detect)",
                    )
                    speed_slider = gr.Slider(
                        minimum=0.5,
                        maximum=2.0,
                        value=1.0,
                        step=0.1,
                        label="Speed",
                    )
                    temperature_slider = gr.Slider(
                        minimum=0.1,
                        maximum=1.5,
                        value=0.7,
                        step=0.1,
                        label="Temperature (creativity)",
                    )
                    generate_btn = gr.Button("🎵 Generate Audio", variant="primary")
                    output_audio = gr.Audio(label="Generated Audio")
                    output_message = gr.Textbox(label="Status", interactive=False)

            generate_btn.click(
                fn=generate_speech,
                inputs=[text_input, voice_dropdown, language_dropdown, speed_slider, temperature_slider],
                outputs=[output_audio, output_message],
            )

        # Tab 2: Voice Cloning
        with gr.Tab("🎤 Voice Cloning"):
            with gr.Row():
                with gr.Column(scale=2):
                    clone_text_input = gr.Textbox(
                        label="Text to convert",
                        placeholder="Enter your text here...",
                        lines=8,
                    )
                    voice_file_input = gr.Audio(
                        label="Upload voice sample (5-60 seconds recommended)",
                        type="filepath",
                    )
                    voice_name_input = gr.Textbox(
                        label="Voice profile name",
                        placeholder="my-voice",
                    )
                with gr.Column(scale=1):
                    clone_language_dropdown = gr.Dropdown(
                        choices=[
                            "auto",
                            "en", "pt", "es", "fr", "de", "it", "ja", "ko", "zh",
                            "ru", "nl", "pl", "tr", "ar", "hi", "sv", "no", "da",
                            "fi", "el", "cs", "uk", "vi"
                        ],
                        value="auto",
                        label="Language",
                    )
                    clone_speed_slider = gr.Slider(
                        minimum=0.5,
                        maximum=2.0,
                        value=1.0,
                        step=0.1,
                        label="Speed",
                    )
                    clone_btn = gr.Button("🎭 Clone Voice & Generate", variant="primary")
                    clone_output_audio = gr.Audio(label="Generated Audio")
                    clone_output_message = gr.Textbox(label="Status", interactive=False)

            clone_btn.click(
                fn=clone_voice_and_generate,
                inputs=[clone_text_input, voice_file_input, voice_name_input, clone_language_dropdown, clone_speed_slider],
                outputs=[clone_output_audio, clone_output_message],
            )

        # Tab 3: Output Files
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
        - For best results, upload 5-60 seconds of clear speech for voice cloning
        - Use lower temperature (0.3-0.5) for more stable output
        - Adjust speed to match your preferred narration pace
        - Supported languages: English, Portuguese, Spanish, French, German, Italian, Japanese, Korean, Chinese, and more
        """
    )


if __name__ == "__main__":
    demo.launch(
        server_name="0.0.0.0",
        server_port=7860,
        share=False,
        show_error=True,
    )
