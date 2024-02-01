#include "../shared.hlsl"

#define ShaderRootSignature \
	"RootFlags(ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT), " \
	\
	"RootConstants(num32BitConstants=1, b0), " \
	\
	"DescriptorTable( " \
		"SRV(t0, space=8) " \
	"), " \
	\
	"DescriptorTable( " \
		"Sampler(s0, space=8), " \
		"Sampler(s1, space=8) " \
	"), " \
	\
	"RootConstants(num32BitConstants=" HDR_PLUGIN_CONSTANTS_SIZE ", b3), "
