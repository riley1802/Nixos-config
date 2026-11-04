---
name: "lfm3-helper"
description: "Build system prompts, harness files, mode prompts, or d1 question specs for Liquid AI's LFM3 models, and answer LFM3 spec/setup questions. Use for any LFM3, d1-2B, or Liquid model prompt work."
---

# LFM3 Helper

This skill does two jobs:

1. **Build prompt text**: a full system prompt, a harness file (Hermes `SOUL.md`, Pi `APPEND_SYSTEM.md`), a tool description, a mode prompt for the audio/omni models, or a question spec for the d1 decision models.
2. **Answer questions** about the LFM3 family: specs, formats, settings, what each model is (and isn't) good at.

## Freshness: read this first

LFM3 was released on **27 Oct 2026**, after your training data. Do not answer from memory: older LFM2/LFM2.5 knowledge is actively misleading here because the tool-call format, context lengths, and sampling defaults all changed. Everything you need is in the reference sections at the bottom of this file, snapshotted from Liquid's Hugging Face model cards on 31 Oct 2026.

If a question hinges on something that moves fast (minimum llama.cpp build, vLLM/SGLang support status, a harness config key) and you have Hugging Face or web tools, re-check the live model card before stating it. If you can't check, say the reference date.

## Reference sections: what to read when

The references are appended below as `# Reference: <name>` sections. Jump to the one you need instead of reading all of them.

| Section | Read when |
|---|---|
| `family.md` | Always, first. Lineup, which model fits which job, shared facts. |
| `text-1.7b.md` | LFM3-1.7B: chat template, thinking, tool calls, deferred tools. |
| `vision-vl.md` | LFM3-VL-2B. |
| `audio-omni.md` | LFM3-Audio-2B or LFM3-Omni-2B. Has the exact fixed mode prompts. |
| `decision-d1.md` | d1-2B or d1-Omni-2B. These take question specs, not system prompts. |
| `runtimes.md` | llama.cpp, Hermes Agent, Pi (plus OpenClaw/vLLM briefly): where prompt text goes and how to serve. |
| `prompt-writing.md` | Any time you draft prompt text. |

---

## Job 1: Answering questions

1. Read `family.md`, then the relevant model file.
2. Answer first, then only the context the answer needs.
3. Link the model card (`https://huggingface.co/LiquidAI/<model>`) for anything the user may want to verify.
4. If the references don't cover it, say so plainly and check the live card if you can. Don't fill gaps with LFM2.5 details.

---

## Job 2: Building prompt text

The user asked for a **full interview before any drafting**. A 2B model can't infer intent the way a frontier model can: a vague prompt produces generic, drifting behavior. So every specific has to come from the user, and the interview is where you get it.

### Step 1: Interview (no drafting yet)

Ask in rounds of up to 4 questions. Use the multiple-choice question tool if one is available (the user can always type a custom answer), otherwise ask in plain text. Skip anything the user already answered. Don't re-ask it.

**Round 1: always**
- **Which model?** (1.7B text / VL-2B / Audio-2B / Omni-2B / d1-2B / d1-Omni-2B). If unsure, help them pick using `family.md`.
- **Which runtime?** llama.cpp (raw server or CLI), Hermes Agent, Pi, or other. **If the user didn't state it, always ask; never assume.** It decides where the text goes and what's already in the prompt around it.
- **What piece of text?** Full system prompt, Hermes `SOUL.md` / custom personality, Pi `SYSTEM.md` vs `APPEND_SYSTEM.md`, tool descriptions, an audio/omni mode prompt, d1 questions.
- **The job in one sentence:** what should the model do?

**Round 2: the job's details**
- Who or what sends it messages (a person, a script, another agent)? What inputs arrive (text, images, audio, JSON)?
- Exact output: free text, JSON (with which fields), a single label, spoken reply?
- Tools: names and what each does. Do they already have schemas?
- Thinking on or off (1.7B/VL think by default; Omni can't), language(s), length limits.
- Hard limits: things it must never do.

**Round 3: only if still fuzzy**
- An example of a good output and a bad one.
- What it should do when unsure, out of scope, or missing info.
- How the user will tell whether the prompt works.

**Branches that change the interview:**
- **d1 models:** there is no system prompt. Interview about the *decision* instead: what the state is (text/JSON/image/video/audio), each question, its type, and the options or levels. See `decision-d1.md`.
- **Audio/Omni models:** first check whether the task matches a built-in mode (ASR, TTS, voice chat, translation, audio/image understanding). If it does, the answer is mostly the exact fixed string from `audio-omni.md`. Only interview further for any custom text around it.
- **Harnesses (Hermes, Pi):** the harness already sends a big prompt with its own tool guidance. Ask whether they want to *replace* or *add to* it (see `runtimes.md`). Adding is usually right for a small model.

Before drafting, play back a 3–5 line summary of what you understood and get a yes.

### Step 2: Draft

Follow `prompt-writing.md`. Also apply the model file's hard rules: correct mode strings, no special tokens in content, no hand-pasted tool schemas when the template inserts them.

### Step 3: Deliver

Give, in this order:
1. **The text** in a code block, ready to paste.
2. **Where it goes**: exact file path, CLI flag, or API field for their runtime.
3. **Settings to pair with it**: sampling params, thinking on/off, context size, from the model file.
4. **One test message** they can send to confirm it behaves, and what a good response looks like.
5. **Assumptions** you made, if any, in one line each.

Then offer to tighten it after they test it. Small-model prompts usually need one round of real-world fixes.

---

# Reference: family.md

Snapshot: Liquid AI Hugging Face model cards, read 31 Oct 2026. Release date: 27 Oct 2026.
Blog: https://www.liquid.ai/blog/lfm3 · Collection: https://huggingface.co/collections/LiquidAI/lfm3

### The lineup

Every model branches from one base, **LFM3-1.7B-Base** (1.73B params). License for all: **LFM Open License v1.0**.

| Model | Repo | Params | Context | In → Out | Thinks? | Best for |
|---|---|---|---|---|---|---|
| LFM3-1.7B | `LiquidAI/LFM3-1.7B` | 1.73B | 256K | text → text | Yes, on by default | Local agents, tool calling, structured output, fine-tuning |
| LFM3-VL-2B | `LiquidAI/LFM3-VL-2B` | 1.92B | 128K | text + image + video → text | Yes | Video Q&A, documents/charts/app screens, object finding, spatial reasoning |
| LFM3-Audio-2B | `LiquidAI/LFM3-Audio-2B` | 2B | 32K | text/audio → text/speech | Optional (text-only answers) | ASR, TTS, voice chat, speech translation, spoken tool calls |
| LFM3-Omni-2B | `LiquidAI/LFM3-Omni-2B` | 2.17B | 32K | text + image + video + audio → text/speech | **No**, non-reasoning | One model replacing ASR + VLM + LLM + TTS on device |
| d1-2B | `LiquidAI/d1-2B` | 1.92B | 128K | state + images/video + questions → typed answers | n/a (no generation) | Routing, classification, moderation, extraction, visual inspection |
| d1-Omni-2B | `LiquidAI/d1-Omni-2B` | 2.17B | 128K | same as d1-2B + audio | n/a | Decisions that depend on what's heard (call routing, sound events) |

All six have GGUF builds (`<repo>-GGUF`); MLX and ONNX builds exist for most; FP8/NVFP4 builds for the 1.7B and VL. Liquid says the 1.7B at 4-bit takes about 1 GB of memory.

### Shared facts

- **Architecture ("tri-hybrid"):** 24 layers: 13 gated short convolutions, 5 sliding-window attention, 6 global attention. Vocabulary 128,000.
- **Text languages (16):** English, Arabic, Chinese, French, German, Italian, Japanese, Korean, Portuguese, Spanish, Vietnamese, Thai, Indonesian, Hindi, Russian, Polish.
- **Speech languages (Audio/Omni):** Arabic, Danish, German, Greek, British English, American English, Finnish, French, Hebrew, Italian, Japanese, Korean, Dutch, Polish, Portuguese, Spanish, Swedish, Turkish, Chinese.
- **Chat format:** ChatML-style (`<|startoftext|><|im_start|>system ... <|im_end|>`). Liquid's default system line: `You are a helpful assistant trained by Liquid AI.`
- **Tool calls (all generating models):** XML, a superset of `qwen3_coder`. **Changed from LFM2/LFM2.5**, which used `<|tool_call_start|>` and Pythonic calls. Details in `text-1.7b.md`.
- **Fine-tuning:** every model fine-tunes on a single GPU. 1.7B has TRL notebooks (SFT, DPO, GRPO, CPT); Audio/Omni have Transformers SFT notebooks.

### Stated limits (from Liquid's own cards)

- 1.7B and Audio: "not recommended for agentic coding or complex multi-step reasoning due to its small size." Use retrieval/search for knowledge-heavy tasks.
- VL: "not recommended for coding, multi-turn conversations, or complex reasoning."
- d1: "not a chat model." Less reliable past ~64K tokens of state; estimates are good on counts/scores, weaker on free quantities.
- d1-Omni: long spoken passages lose accuracy, most of all outside Latin-script languages. Without audio, use d1-2B instead.

### Picking a model: quick routing

- Chatting, agents, tools, JSON output, text only → **LFM3-1.7B**
- Need to look at images or video, text answer → **LFM3-VL-2B** (strongest vision, can think)
- Speech in or out, no vision → **LFM3-Audio-2B**
- Mixed vision + speech in one model, or video *with its soundtrack* → **LFM3-Omni-2B**
- A fixed decision/label/extraction per input, need probabilities and speed → **d1-2B** (or **d1-Omni-2B** if audio matters)

### Benchmarks (Liquid-reported, 1.7B)

Liquid's card claims LFM3-1.7B "can power agentic applications that used to need 9B parameters." Selected agent scores, LFM3-1.7B vs Qwen3.5-9B: LiveClaw 45.60 vs 35.77; Claw-Eval General avg 68.64 vs 66.53. These are vendor-measured numbers. Present them as Liquid's claims, not independent results.

# Reference: text-1.7b.md

Card: https://huggingface.co/LiquidAI/LFM3-1.7B · GGUF: https://huggingface.co/LiquidAI/LFM3-1.7B-GGUF

Post-trained text model for local agents, tool calling, structured output, and fine-tuning. Liquid says it was post-trained for the agent harnesses **Hermes Agent, Pi, and OpenClaw**. 256K context (input + output).

### Sampling (Liquid-recommended)

- **General** (chat, tool use, agents, coding): `temperature=0.1, top_k=50, repetition_penalty=1.1`
- **Math & STEM:** `temperature=1.0, top_p=0.95, top_k=20`
- llama.cpp: `--temp 0.1 --top-k 50 --repeat-penalty 1.1`

### Chat template

```text
<|startoftext|><|im_start|>system
You are a helpful assistant trained by Liquid AI.<|im_end|>
<|im_start|>user
Explain how a heat pump works.<|im_end|>
<|im_start|>assistant
<think>
```

- Let the runtime apply this (`apply_chat_template(..., add_generation_prompt=True)`, or llama.cpp's built-in template). Never type these tokens into prompt *content*.
- **Thinking is on by default.** `enable_thinking=False` disables it, but Liquid warns this "can be inconsistent, especially for reasoning-heavy tasks." So don't write "do not think" into a system prompt and expect it to stick.
- Reasoning from turns before the latest user message is stripped unless `preserve_thinking=True`. A system prompt shouldn't rely on the model remembering its earlier reasoning.

### Tool calling

Pass schemas through `tools=` (Transformers) or the OpenAI-style `tools` field (servers). **The template inserts them into the system prompt between `<tools>` and `</tools>`, one JSON line per tool.** So don't also paste schemas into your system prompt text: they'd appear twice and waste context.

Tool definition shape:
```json
{"type": "function", "function": {"name": "...", "description": "...", "parameters": {"type": "object", "properties": {...}, "required": [...]}}}
```

Model output (XML, superset of `qwen3_coder`):
```text
<tool_call>
<function=get_weather>
<parameter=city>
Paris
</parameter>
</function>
</tool_call>
```

- The model usually writes `<think>…</think>` before the call.
- Parsed argument values arrive as strings; convert types. Non-string values are written as JSON.
- In history: add the assistant `tool_calls` entry (`arguments` as a **dict**, not a JSON string; `json.loads()` first), then a `tool` message with the result. The template wraps results in `<tool_response>`.
- Keep passing the same `tools` every request and keep the current tool turn's content and reasoning in history.
- Decode with `skip_special_tokens=False` when parsing tool calls, `True` for the final answer.

#### What this means for prompt text

The system prompt should say **when** to use each tool and what to do with results. The template already covers **what** the tools are. Good tool descriptions (the `description` field) matter a lot at 2B. See `prompt-writing.md`.

### Deferred tools / tool search

For big tool catalogs (Liquid flags 100+ tools), mark tools `"defer_loading": true`. They stay in your `tools` list but out of the prompt. Keep one search tool always loaded (Liquid suggests naming it `search_tools`). When it returns `{"type": "tool_reference", "name": "..."}` parts in a `tool` message, the template inserts the full definitions into an `<additional_tools>` block. That leaves the system prompt unchanged and the prompt cache valid.

Liquid's recommended system-prompt wording for this setup:

> You only have one tool right now: search_tools, which searches a catalog of many more tools. If none of your current tools can handle a request, call search_tools to find one, then call the tool it returns.

Rules: pass all tools (deferred too) on every request. The template errors if a `tool_reference` names a tool not in `tools`. Works on vLLM, SGLang, and LFM3-compatible llama.cpp builds; for llama.cpp use a GGUF with the current template or `--chat-template-file`.

### Good fits / poor fits

- Good: tool-calling agents, extraction to JSON, classification-by-generation, RAG answering, narrow assistants, fine-tuning targets.
- Poor (Liquid's words): agentic coding, complex multi-step reasoning, knowledge-heavy questions without retrieval.

### GGUF notes

- Requires llama.cpp **b11960 (v0.8.0)** or newer. Distro packages (e.g. nixpkgs) can lag, so check the version.
- `LFM3-1.7B-QAD-Q4_0.gguf` is a quantization-aware-distilled Q4_0 trained to recover Q4 accuracy loss. It's a good default for low memory.
- Ollama: `ollama run lfm3` (card lists macOS, Ollama ≥ v0.40.12). LM Studio: llama.cpp engine ≥ 2.65.1.

# Reference: vision-vl.md

Card: https://huggingface.co/LiquidAI/LFM3-VL-2B · GGUF: https://huggingface.co/LiquidAI/LFM3-VL-2B-GGUF

1.92B params: 1.73B LFM3 language model + 164M vision encoder + 25M projector. **First LFM vision model with video input.** 128K context.

### What it's for

Liquid lists: questions about video, reading documents/charts/app screens, finding objects, spatial reasoning for robotics. It **thinks step by step** before answering, which helps most on math, charts, and multi-step visual questions.

**Not recommended** (Liquid): coding, **multi-turn conversations**, complex reasoning. So design prompts for single-shot "here's the image/video, answer this," not long chats.

### Inputs

- Images and video at native resolution. Each 2×2 block of 16×16 patches becomes one token, so big images cost a lot of context.
- Video sampled at **2 fps, 4–768 frames** by default. llama.cpp always uses these values (`--video-fps` has no effect). Video needs `ffmpeg` in `PATH`.

### Sampling

`temperature=0.1, top_p=1.0, top_k=50, min_p=0.0, repetition_penalty=1.1`. Generation can be long with reasoning; set a generous max tokens (card example: 16384).

### Chat template

```text
<|startoftext|><|im_start|>system
You are a helpful assistant trained by Liquid AI.<|im_end|>
<|im_start|>user
<|vision_start|><|image|><|vision_end|>What species is in this picture?<|im_end|>
<|im_start|>assistant
<think>
```

- The template inserts `<|vision_start|><|image|><|vision_end|>` / `<|video|>` itself. **Never put these tags in message content or the system prompt.**
- Reasoning from earlier turns is stripped unless `preserve_thinking=True`.
- No fixed mode prompts: write a normal system prompt.

### Tool calling

Same XML format as the 1.7B (see `text-1.7b.md`). The card carries Liquid's warning that the format changed from LFM2/LFM2.5 to a superset of `qwen3_coder`.

### Running

llama.cpp (b11960+; `-hf` also downloads the mmproj vision projector):
```bash
llama serve -hf LiquidAI/LFM3-VL-2B-GGUF:Q4_0 \
  --temp 0.1 --top-p 1.0 --top-k 50 --min-p 0.0 --repeat-penalty 1.1 \
  --no-reasoning-preserve --port 8080
```
One-shot: `llama cli` with the same flags plus `--image <path>` or `--video <path>` and `-p "<prompt>"`.

vLLM/SGLang: as of the snapshot, VL support in both was **still in progress/review**. The card shows intended commands using `--reasoning-parser qwen3 --tool-call-parser qwen3_coder` for vLLM. Check the live card before relying on it.

### Prompt-writing notes for VL

- Say what to look at and what to return ("Read the total from the receipt. Reply with only the number.").
- For grounding, borrow Omni's tested phrasing: "Answer questions about the provided image. Base every answer only on what can be seen." (that string is documented for Omni, not VL; it's plain English, but untested by Liquid on VL).
- For long videos, lower fps/max frames in the runtime rather than asking the model to "skim."

# Reference: audio-omni.md

Cards: https://huggingface.co/LiquidAI/LFM3-Audio-2B · https://huggingface.co/LiquidAI/LFM3-Omni-2B
GGUF: `LiquidAI/LFM3-Audio-2B-GGUF`, `LiquidAI/LFM3-Omni-2B-GGUF`

These models switch behavior on **fixed system-prompt strings**. Copy them exactly. Paraphrasing them ("Please transcribe this") is the most common way to break them. The two models' strings are similar but **not identical** (translation in particular), so use the right column.

### Model facts

| | Audio-2B | Omni-2B |
|---|---|---|
| Params | 2B | 2.17B |
| Inputs | text, 16 kHz audio | text, images, video (with/without soundtrack), 16 kHz audio |
| Outputs | text, 24 kHz speech, interleaved | text, 24 kHz speech, interleaved |
| Context | 32K | 32K |
| Reasoning | optional for text-only answers (prefill `<think>`) | **none**: `enable_thinking=True` unsupported; every turn opens with empty `<think></think>` |
| Voice chat language | **English only** | (not stated as English-only) |
| Video | n/a | 2 fps, 4–384 frames |
| Image tokens | n/a | native res, up to 2,048 tokens/image |

### Fixed mode prompts

Replace `<language>` / `{source}` / `{target}` with English language names. For TTS, English must be `American English` or `British English`; gender is `female` or `male`.

| Task | Audio-2B system prompt | Omni-2B system prompt |
|---|---|---|
| ASR (known language) | `Perform ASR in <language>.` | `Perform ASR in <language>.` |
| ASR (auto-detect) | `Perform ASR.` | (not documented) |
| Live ASR (streaming, English only) | `Perform live ASR.` | (not documented) |
| TTS | `Perform TTS in <language> using a <gender> voice.` + prefill assistant `<\|audio_start\|>` | same string, `generation_mode="audio"` |
| Voice chat (text + speech reply) | `Respond with interleaved text and audio.` + prefill `<\|mixed_start\|>` | `Respond with interleaved text and audio.`, `generation_mode="interleaved"` |
| Speech → text chat | none needed; prefill `<think>` to reason or `<think></think>` for direct | none needed; `Respond with text.` makes it explicit |
| Audio understanding | `Answer questions about the provided audio clip. Base every answer only on what can be heard.` | same |
| Speech → text translation | `Translate the following speech from {source} to {target} in text form.` | `Please translate the following spoken {source} into {target} text.` |
| Text → text translation | `Translate the following {source} text into {target}.` | (not documented; Omni card only gives speech → text) |
| Image Q&A | n/a | `Answer questions about the provided image. Base every answer only on what can be seen.` |
| Image caption | n/a | `Describe the provided image.` |
| Video + soundtrack | n/a | `Answer questions about the video using what you see and hear.` (Transformers also needs `load_audio_from_video=True` and `use_audio_in_video=True`) |
| Multiple choice (Omni) | n/a | put choices in the user text and end it with `Please choose the answer from the options.` |
| Tools + spoken reply | `Respond with function calls, and interleaved text and audio.\n\nList of tools:` (don't prefill; model picks `<tool_call>` or `<\|mixed_start\|>`) | no special prompt shown; template puts tools in `<tools>…</tools>` |
| Tools, text-only reply | `List of tools:` + `suppress_mixed=True, suppress_audio_out=True` | `generation_mode="text"` |

**Omni output-mode suffixes:** append to the *end* of any system prompt to steer output modality. The card's mode table says `Respond in text.` / `Respond in interleaved text and audio.`, while its examples use `Respond with text.` / `Respond with interleaved text and audio.`. Both wordings appear in Liquid's own card. Prefer the "with" forms used in the working examples, and mention the discrepancy if the user hits trouble.

### Combining a custom prompt with a mode

For anything beyond the fixed tasks (e.g. a voice assistant persona), write the custom instructions first and put the mode string **last**. Example for Omni:

```text
You are a kitchen timer assistant. Keep answers under two sentences. Respond with interleaved text and audio.
```

Keep the custom part short. These are 2B models with 32K context, and audio eats tokens fast.

### Sampling

- **Audio-2B:** text: greedy (temp 0). Speech/interleaved: `audio_temperature=1.0, audio_top_k=128, audio_repetition_penalty=1.1, audio_repetition_window=4096`.
- **Omni-2B:** text: greedy (temp 0). Speech/interleaved: `audio_temperature=0.4, audio_repetition_penalty=1.2`.
- In GGUF, the audio sampling params are stored in the file.

### Running with llama.cpp (b11960 / v0.8.0+)

```bash
# Audio
llama serve -hf LiquidAI/LFM3-Audio-2B-GGUF:Q4_K_M --temp 0 --port 8080
llama cli -hf LiquidAI/LFM3-Audio-2B-GGUF:Q4_K_M --audio speech.wav -sys "Perform ASR in English." -p "<__media__>" --temp 0

# Omni (non-reasoning, so turn reasoning off)
llama serve -hf LiquidAI/LFM3-Omni-2B-GGUF:Q4_K_M --reasoning off --temp 0 --port 8080
llama cli -hf LiquidAI/LFM3-Omni-2B-GGUF:Q4_K_M --image photo.png -p "Describe this image." --temp 0

# TTS (either model): --tts-lang (default en), --tts-voice female|male
llama-tts -m LFM3-Audio-2B-Q4_K_M.gguf -mm mmproj-LFM3-Audio-2B-Q8_0.gguf -p "Hello world" --tts-voice male -o out.wav
```

- `-sys` sets the system prompt in `llama cli`. That's where mode strings go.
- `llama serve` exposes a **`/v1/realtime` WebSocket** for real-time voice conversations with tool calls (both models).
- Video needs `ffmpeg` in `PATH`.

# Reference: decision-d1.md

Cards: https://huggingface.co/LiquidAI/d1-2B · https://huggingface.co/LiquidAI/d1-Omni-2B · Blog: https://www.liquid.ai/blog/open-d1

**These are not chat models and take no system prompt.** They read a *state* plus a set of named *questions* and return typed, calibrated answers with probabilities in **one forward pass**, generating no tokens. There are no sampling parameters. The "prompt text" you build for them is the **question spec**.

- d1-2B: built on LFM3-VL-2B, 1.92B. State = text/JSON, pictures, or video.
- d1-Omni-2B: built on LFM3-Omni-2B, 2.17B. Adds audio clips and **spoken questions**. Without audio, prefer d1-2B (stronger on text and single boxes, better calibrated).
- Speed (Liquid): 5.7 ms/decision on H100, 3.8 ms on MI325X; any number of questions about one state per call.
- 128K context, but answers get less reliable past ~64K tokens of state.

### Question types

| `type` | Asks | Returns |
|---|---|---|
| `noul` | yes/no | `noul` = P(yes) |
| `choice` | one option from `criteria` (`{name: description}`) | `choice`, `confidence`, `probabilities` |
| `choice` + `"multiple": true` | any options | `choices`, per-option `probabilities` |
| `score` | one of 2–10 ordered levels; `criteria` is a list, **lowest first** | `score` (median level), `confidence`, `probabilities`, `legend` |
| `text` / `number` / `date` | a value read from the state | the value (number with `unit`, date ISO 8601), `span`, `found` |
| `number` + `range` (+ `step`) | an estimate | `number` (median), `interval` (p10, p90) |
| `box` / `boxes` | one object / every instance (≤16, or `max`) in the one picture | `box` {top, bottom, left, right as fractions}, `found`, `confidence` / `boxes`, `count` |

A value or box is `None` when `found` < 0.5. **Calibrate decision thresholds on your own data.**

### Example spec

```python
questions = {
    "refund":  {"type": "noul", "instructions": "Is the customer asking for a refund?"},
    "team":    {"type": "choice", "instructions": "Which team should handle this?",
                "criteria": {"billing": "Charges, refunds, invoices",
                             "shipping": "Delivery and parcels",
                             "technical": "App or site faults"}},
    "urgency": {"type": "score", "instructions": "How urgent is this ticket?",
                "criteria": ["low", "medium", "high"]},
}
out = model.system_one("I was charged twice and my parcel never arrived.", questions)
```

Batch: `model.system_one_batch([(state, questions[, media]), ...])`. `set_size=` (default 16) = how many questions are read together. Larger is faster but costs some text accuracy.

d1-Omni media: `{"type": "audio", "path": "call.wav"}` (16-bit PCM WAV, resampled to 16 kHz). A spoken question replaces the text: `{"type": "noul", "instructions": {"type": "audio", "path": "question.wav"}}`.

### Running d1-2B with llama.cpp (b11960+)

**Supported only:** `noul`, `choice`, `score`. **Not yet:** `multiple: true`, extraction (`text`/`number`/`date`), estimates, boxes. Those need Transformers.

```bash
llama-server -hf LiquidAI/d1-2B-GGUF:Q8_0 -b 8192 -ub 8192
curl http://127.0.0.1:8080/v1/systemone -H "Content-Type: application/json" -d '{
  "state": "I was charged twice this month, please refund one of them.",
  "questions": {
    "refund": {"type": "noul", "instructions": "Is the customer asking for a refund?"}
  }
}'
```

- `-b`/`-ub` must hold the whole state + media in one batch; a picture uses at most half of `-ub` (8192 keeps the full 4,096-token picture budget).
- Images: `"images": ["data:image/jpeg;base64,..."]`; video: `"files": ["data:video/mp4;base64,..."]` (needs `ffmpeg`). `"state": null` when media is the whole state.
- d1-Omni-2B GGUF exists (`LiquidAI/d1-Omni-2B-GGUF`); its llama.cpp support details weren't captured in this snapshot, so check that card.

### Writing good question specs

- **`instructions` is a direct question** about the state, as in Liquid's examples. Not a role prompt, not "You are a classifier…".
- **`choice` criteria:** short, concrete, *mutually exclusive* descriptions. Overlapping options split probability mass and hurt calibration. Add an explicit catch-all option ("other": "None of the above") if real inputs can fall outside.
- **`score` criteria:** ordered lowest → highest, 2–10 levels, each level distinguishable ("Can wait" / "Today" / "Blocking the customer now" beats "low/med/high" when the edges matter).
- **One decision per question.** Split "Is it urgent and about billing?" into two.
- Name questions with short snake_case keys; they come back as answer keys.
- Use `noul` probabilities with a threshold you tune, rather than treating 0.5 as truth.
- Keep the state lean: put only what the decision needs in it (strip boilerplate, signatures, long logs).

# Reference: runtimes.md

Covers the user's main setups (llama.cpp, Hermes Agent, Pi), plus OpenClaw and vLLM briefly.

**Important caveat:** Liquid's official harness guide (https://docs.liquid.ai/examples/agent-harnesses) was still written for **LFM2.5** at snapshot time. The Hermes/Pi/OpenClaw commands below follow that guide's structure with LFM3 values swapped in. The *structure* is from Liquid; the LFM3-specific values (model id, context) are adaptations. Say so when giving them.

---

### llama.cpp

**Minimum version for every LFM3 GGUF: b11960 (v0.8.0).** Check with `llama-server --version` (or `llama --version`). Distro packages, nixpkgs included, may lag behind; build from source or use a newer package if it's too old.

Two command styles appear in Liquid's cards: the newer unified `llama serve` / `llama cli`, and the classic `llama-server` / `llama-cli`. Both are valid on v0.8.0+.

#### Serving the 1.7B (OpenAI-compatible API at :8080)

```bash
llama-server -hf LiquidAI/LFM3-1.7B-GGUF:Q4_K_M \
  --jinja --port 8080 -c 65536 -ngl 99 \
  --temp 0.1 --top-k 50 --repeat-penalty 1.1
```

- Sampling: from the LFM3-1.7B card.
- `--jinja`: Liquid's LFM2.5 guide says omitting it disables tool calling on `llama-server`. LFM3 cards (using `llama serve`) don't show it. Include it: it's harmless, and if tool calls come back as raw text instead of parsed `tool_calls`, missing `--jinja` is the first suspect.
- `-c`: the model supports 262144 (256K), but KV memory grows with it. Start around 32K–64K and raise if the agent's history overflows. Whatever you pick, the harness's context setting must match it.
- `-ngl 99` offloads all layers to GPU; `-fa on` (flash attention) works on CUDA/Metal builds.
- Deferred tools need a GGUF with the current chat template, or `--chat-template-file <path>`.
- Verify: `curl http://localhost:8080/v1/models` (this also shows the model id to use in harness configs).

#### Where system prompt text goes

- **API:** first message `{"role": "system", "content": "..."}` in `/v1/chat/completions`.
- **One-shot CLI:** `llama cli ... -sys "your system prompt"` (this is how Liquid's cards pass audio/omni mode strings).
- **Tools:** send them in the request's `tools` field. The template places them in the system prompt automatically, so don't duplicate them in your text.

---

### Hermes Agent (Nous Research)

#### Connect to llama.cpp (pattern from Liquid's guide)

```bash
hermes config set model.provider custom
hermes config set model.base_url http://localhost:8080/v1
hermes config set model.default <id from /v1/models>
hermes config set model.context_length 65536   # match your llama.cpp -c
hermes config set model.api_mode chat_completions
hermes config set agent.tool_use_enforcement true
```

**`agent.tool_use_enforcement true` matters.** Liquid's guide warns that without it, the (LFM2.5) model "tends to describe actions instead of calling tools". Assume the same risk for LFM3. If `web_search` is missing, remove `search`/`browser` from `agent.disabled_toolsets` and restart.

#### Where custom prompt text goes

Hermes builds the system prompt as a stack, in this order:
1. **`SOUL.md`**: agent identity, slot #1 (falls back to the built-in Hermes identity if empty/missing)
2. tool-aware behavior guidance
3. memory/user context
4. skills guidance
5. context files (`AGENTS.md`, `.cursorrules`)
6. timestamp
7. platform formatting hints
8. optional overlays like `/personality`

Options:
- **`~/.hermes/SOUL.md`** (or `$HERMES_HOME/SOUL.md`): persistent identity, tone, and style. Loaded **only** from HERMES_HOME, never the working directory. Hermes seeds a starter file and won't overwrite yours. Content is scanned for prompt-injection patterns (so avoid text that *looks* like injection: "ignore previous instructions", fake system tags) and **truncated if too large**. Restart the session after editing.
- **`AGENTS.md`** in a project: project-specific instructions. Hermes's docs: if it should follow you everywhere, it belongs in SOUL.md; if it belongs to a project, it belongs in AGENTS.md.
- **Named personalities**: `~/.hermes/config.yaml`:
  ```yaml
  agent:
    personalities:
      codereviewer: >
        You are a meticulous code reviewer. ...
  ```
  then `/personality codereviewer` for a session-level overlay.
- Hermes docs also mention an `agent.system_prompt` setting affecting how Hermes speaks; its exact semantics weren't captured. Check Hermes docs before recommending it.

**For LFM3 in Hermes:** keep SOUL.md short (identity + 5–10 style rules). Everything in slots 2–8 is already eating a 2B model's attention budget, and SOUL.md gets truncated if it's long anyway.

---

### Pi (pi-coding-agent, Earendil Works)

#### Connect to llama.cpp (pattern from Liquid's guide)

`~/.pi/agent/models.json`:
```json
{
  "providers": {
    "local": {
      "baseUrl": "http://localhost:8080/v1",
      "api": "openai-completions",
      "apiKey": "local",
      "models": [{ "id": "<id from /v1/models>" }]
    }
  }
}
```
Run `pi`, select with `/model`. If Pi flags unsupported features, add `"compat": { "supportsReasoningEffort": false }` to the model entry.

#### Where custom prompt text goes

- **`APPEND_SYSTEM.md`**: *adds* to Pi's default prompt. Use `.pi/APPEND_SYSTEM.md` for a project or `~/.pi/agent/APPEND_SYSTEM.md` globally. **Usually the right choice for LFM3**: Pi's default prompt lists the enabled tools and tool-specific guidelines, which a small model needs.
- **`SYSTEM.md`**: *replaces* the default prompt, again as `.pi/SYSTEM.md` or `~/.pi/agent/SYSTEM.md`. Only use it if the user wants full control. Then the replacement must itself explain the tools and when to use them.
- **`AGENTS.md`** (falls back to `CLAUDE.md`): conventions/project context, loaded from `~/.pi/agent/`, every parent dir, and the cwd, then concatenated. `AGENTS.override.md` replaces a directory's AGENTS.md. Disable with `--no-context-files` / `-nc`.

Pi's default prompt order: identity → available tools → guidelines → doc references → APPEND_SYSTEM.md content → AGENTS.md files → skills list.

---

### OpenClaw (brief)

Pattern from Liquid's guide: add a provider under `models.providers` with `baseUrl: "http://localhost:8080/v1"`, `api: "openai-completions"`, the model id, `contextWindow`, and `maxTokens`. Select it via `agents.defaults.model.primary: "local/<id>"`. Open with `openclaw dashboard`. Where OpenClaw takes custom prompt text wasn't captured, so check OpenClaw docs.

### vLLM / SGLang (brief)

- 1.7B BF16 runs on vLLM, SGLang, and Transformers. FP8/NVFP4 variants are listed for SGLang.
- Tool parsing: the LFM3 format is a `qwen3_coder` superset. The VL card's (pending-support) vLLM command uses `--reasoning-parser qwen3 --enable-auto-tool-choice --tool-call-parser qwen3_coder`. The 1.7B card doesn't state parser flags. Liquid's older guide's `--tool-call-parser lfm2` is for LFM2/2.5 and **should not be assumed for LFM3**.
- Default ports: llama.cpp 8080, vLLM 8000, SGLang 30000, LM Studio 1234.

# Reference: prompt-writing.md

Two kinds of guidance here, kept separate on purpose:
- **Liquid-stated**: from Liquid's cards/docs. Treat as fact.
- **Small-model practice**: general experience with ~2B instruction models, not Liquid-specific claims. When you explain *why* a draft is shaped a certain way, attribute it this way rather than as a Liquid rule.

### Liquid-stated facts that shape every prompt

- Default system prompt: `You are a helpful assistant trained by Liquid AI.` That's the baseline your text replaces.
- Positioning: local agents, tool calling, structured output, domain specialization. **Not** agentic coding or complex multi-step reasoning; use retrieval for knowledge.
- Low temperature (0.1) for chat/tools/agents, so the prompt has to do the steering, not sampling luck.
- 1.7B and VL think by default; disabling thinking is unreliable. Omni never thinks. Earlier-turn reasoning is stripped from history.
- Tool schemas are inserted by the template between `<tools></tools>`. Don't repeat them in prose.
- Audio/Omni fixed mode strings must be exact (see `audio-omni.md`).
- d1 takes question specs, not prompts (see `decision-d1.md`).

### Small-model practice

**Shape**
- Short and literal. Aim for under ~250 words for a standalone system prompt, less inside a harness that already adds its own stack. Every extra sentence competes for a 2B model's attention.
- One instruction per line, imperative voice ("Reply in JSON." not "It would be good if replies were JSON").
- Put the role and the single most important rule first. Put the output format at the end, right before the conversation starts.
- Say what TO do. Small models handle "Reply with only the label" better than a stack of "don't"s. Keep a short explicit "Never" list only for true hard limits.
- No conflicting rules, no "use your judgment" escape hatches, no vague words ("appropriately", "when relevant") without saying what that means.

**Make it concrete**
- Give one short example of the exact output format. A 2B model copies format from an example far more reliably than from a description.
- Name things exactly: tool names, field names, label names, matching the schema character for character.
- Tell it what to do when stuck: unclear input, missing info, out-of-scope request. ("If the request is not about recipes, reply: `I can only help with recipes.`")

**Tools**
- The system prompt covers *when* to call which tool and what to do with results. The schema `description` covers *what* the tool does. Write those descriptions too if the user hasn't: one plain sentence, plus units and allowed values in parameter descriptions.
- Add an explicit trigger: "To check the weather, call `get_weather`. Do not guess the weather." Small models otherwise narrate an action instead of taking it (Liquid's guide noted this on LFM2.5 in Hermes).
- Many tools (dozens+): suggest deferred tools + `search_tools` and use Liquid's wording (in `text-1.7b.md`).

**Don'ts**
- Don't put chat-template tokens (`<|im_start|>`, `<think>`, `<|vision_start|>`, `<tool_call>`) in the text.
- Don't ask it to "think step by step". It already thinks, and that just burns tokens.
- Don't paste reference knowledge into a system prompt hoping it learns it. For anything over a paragraph, recommend retrieval (tool or RAG) or fine-tuning, since the model is built to be specialized via single-GPU fine-tuning.
- In Hermes, avoid text that looks like prompt injection; SOUL.md is scanned.

### Skeleton (adapt, don't fill mechanically)

```text
You are <role> for <who/what>.

Your job: <one sentence>.

Rules:
- <most important rule>
- <rule>
- <rule>

Tools:
- Use <tool> when <trigger>. <What to do with the result.>

If <unclear/out-of-scope case>: <exact behavior>.

Output format:
<one concrete example>
```

Drop any section that doesn't apply. For a Hermes `SOUL.md`, drop Tools and Output format (Hermes handles those layers) and keep identity, style, and avoid-lists. For a Pi `APPEND_SYSTEM.md`, skip identity (Pi's default has one) and give project-specific rules only.

### Self-check before delivering

- Could a literal-minded reader follow every line without guessing?
- Is every tool, field, and label name spelled exactly as in the schema?
- Is there an example of the output?
- Is the "when stuck" behavior defined?
- Any template tokens, duplicated schemas, or contradictory rules? Remove them.
- For audio/omni: is every mode string character-for-character from `audio-omni.md`?