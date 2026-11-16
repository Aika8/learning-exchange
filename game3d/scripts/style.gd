## Pattern: Strategy — the art style of the 3D game, decided in one place. The default is stylised low-poly: flat
## colours from one palette, meshes built in code, people read by silhouette (ADR-0024). `--pbr` brings back the
## Poly Haven PBR look of ADR-0019. The ink post-effect (off / outline / engraving) is `Ink`.
## See docs/adr/0024-game3d-stylised-lowpoly-with-ink.md
class_name Style
extends RefCounted

static var _pbr := -1


## True when the PBR look was asked for on the command line (`-- --pbr`).
static func pbr() -> bool:
	if _pbr < 0:
		_pbr = 1 if "--pbr" in OS.get_cmdline_user_args() else 0
	return _pbr == 1
