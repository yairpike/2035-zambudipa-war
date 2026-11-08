# Asset licences
The Lite edition contains no third-party assets. All visuals are Godot primitive meshes created in code.

## Fonts for Burmese, Thai, and Chinese
`localization/fonts/` holds subsets of Noto Sans Myanmar, Noto Sans Thai, and Noto Sans SC by Google and Adobe, under the SIL Open Font License 1.1 (`localization/fonts/OFL.txt`). They are fallbacks behind the menu faces, so the web build can draw the Burmese, Thai, and Chinese text without system fonts.

## EVA voice callouts
`assets/voices/eva/` holds the command-AI callouts in English, Burmese, Chinese, Thai, and Malay. They were synthesized with Microsoft Edge neural text-to-speech voices (en-SG Luna, my-MM Nilar, zh-CN Xiaoxiao, th-TH Niwat, ms-MY Yasmin) through `tools/eva/make_eva.py`, then filtered to a radio band with ffmpeg. Microsoft's terms for that service output have not been cleared for commercial redistribution, so treat these clips as placeholders and re-record or re-license them before a paid release. `assets/voices/eva/manifest.json` lists every line, its text, and the voice that spoke it.
