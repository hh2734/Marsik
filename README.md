# Marsik

A tiny scripting language that helps different languages talk to each other.

Marsik is a small, complete mini-language you can embed into other programming languages. It's much smaller than Lua and leans on the host language to do the heavy lifting. Think of it as a little *lingua franca* between runtimes. More host languages are planned.

---

## What it's for

Marsik isn't meant to be used on its own. You drop it into an existing app so the host program can:

- run small, sandboxed user scripts,
- pass data between systems written in different languages,
- offer the same tiny scripting layer across multiple runtimes.

The whole language - parser, interpreter, standard library - fits in one file per host language.

---

## License

See the repository for license details.
