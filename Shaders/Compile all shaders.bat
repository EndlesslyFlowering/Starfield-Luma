dxc "HDRComposite\HDRComposite_ps.hlsl" -T ps_6_6 -E PS -D APPLY_MERGED_COLOR_GRADING_LUT -Fo "C:\Games\Starfield\Data\shadersfx\HDRComposite\HDRComposite_E00FF1A_ps.bin"
dxc "HDRComposite\HDRComposite_ps.hlsl" -T ps_6_6 -E PS -Fo "C:\Games\Starfield\Data\shadersfx\HDRComposite\HDRComposite_600FF1A_ps.bin"
dxc "HDRComposite\HDRComposite_ps.hlsl" -T ps_6_6 -E PS -D APPLY_BLOOM -Fo "C:\Games\Starfield\Data\shadersfx\HDRComposite\HDRComposite_700FF1A_ps.bin"
dxc "HDRComposite\HDRComposite_ps.hlsl" -T ps_6_6 -E PS -D APPLY_BLOOM -D APPLY_MERGED_COLOR_GRADING_LUT -Fo "C:\Games\Starfield\Data\shadersfx\HDRComposite\HDRComposite_F00FF1A_ps.bin"
dxc "ScaleformComposite\ScaleformComposite_FFAA_ps.hlsl" -T ps_6_6 -E PS -Fo "C:\Games\Starfield\Data\shadersfx\ScaleformComposite\ScaleformComposite_FFAA_ps.bin"
dxc "ColorGradingMerge\ColorGradingMerge_FF81_cs.hlsl" -T cs_6_6 -E main -Fo "C:\Games\Starfield\Data\shadersfx\ColorGradingMerge\ColorGradingMerge_FF81_cs.bin"
dxc "BinkMovie\BinkMovie_FFAB_ps.hlsl" -T ps_6_6 -E PS -Fo "C:\Games\Starfield\Data\shadersfx\BinkMovie\BinkMovie_FFAB_ps.bin"
dxc "FilmGrain\FilmGrain_FF75_ps.hlsl" -T ps_6_6 -E main -Fo "C:\Games\Starfield\Data\shadersfx\FilmGrain\FilmGrain_FF75_ps.bin"
dxc "PostSharpen\PostSharpen_FF9A_ps.hlsl" -T ps_6_6 -E main -Fo "C:\Games\Starfield\Data\shadersfx\PostSharpen\PostSharpen_FF9A_ps.bin"
dxc "ContrastAdaptiveSharpening\ContrastAdaptiveSharpening_100FF94_cs.hlsl" -T ps_6_6 -E main -Fo "C:\Games\Starfield\Data\shadersfx\ContrastAdaptiveSharpening\ContrastAdaptiveSharpening_100FF94_cs.bin"

pause