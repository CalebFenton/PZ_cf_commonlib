# Changelog

What each version changes for a mod that calls the library, newest first; `## Unreleased`, when
present, holds what changed since the last release. Versions follow semantic versioning
(`AGENTS.md`, Versions).

## Unreleased

- `Squares.hasGridPower(square)`: whether the power grid powers a square as the engine decides,
  whatever a mod's replacement of the Lua-visible `square:hasGridPower()` answers.

## 1.0.0

- The first release: the code Renewable Energy and Enhanced Irrigation share. The
  README's module table says what each module does; each function's doc comment is its contract.
