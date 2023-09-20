dxc "PS_combined_HDRComposite.hlsl" -T ps_6_6 -E PS -D APPLY_MERGED_COLOR_GRADING_LUT -Fo "C:\Games\Starfield\Data\shadersfx\dxil\ps_1490693157.bin"
dxc "PS_combined_HDRComposite.hlsl" -T ps_6_6 -E PS -Fo "C:\Games\Starfield\Data\shadersfx\dxil\ps_2017708854.bin"
dxc "PS_combined_HDRComposite.hlsl" -T ps_6_6 -E PS -D APPLY_BLOOM -Fo "C:\Games\Starfield\Data\shadersfx\dxil\ps_3619086619.bin"
dxc "PS_combined_HDRComposite.hlsl" -T ps_6_6 -E PS -D APPLY_BLOOM -D APPLY_MERGED_COLOR_GRADING_LUT -Fo "C:\Games\Starfield\Data\shadersfx\dxil\ps_4102218325.bin"
dxc "ps_4105314757.hlsl" -T ps_6_6 -E PS -Fo "C:\Games\Starfield\Data\shadersfx\dxil\ps_4105314757.bin"
dxc "cs_580663709.hlsl" -T cs_6_6 -E main -Fo "C:\Games\Starfield\Data\shadersfx\dxil\cs_580663709.bin"
dxc "ps_2410320325.hlsl" -T ps_6_6 -E PS -Fo "C:\Games\Starfield\Data\shadersfx\dxil\ps_2410320325.bin"
dxc "ps_1944109934.hlsl" -T ps_6_6 -E main -Fo "C:\Games\Starfield\Data\shadersfx\dxil\ps_1944109934.bin"
dxc "ps_1963423779.hlsl" -T ps_6_6 -E main -Fo "C:\Games\Starfield\Data\shadersfx\dxil\ps_1963423779.bin"

pause