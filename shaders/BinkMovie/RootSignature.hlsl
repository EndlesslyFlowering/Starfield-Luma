#include "../shared.hlsl"

#define ShaderRootSignature \
	"RootFlags(ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT), " \
	\
	"RootConstants(num32BitConstants=2, b0), " \
	\
	"DescriptorTable( " \
		"SRV(t0, space=8), " \
		"SRV(t1, space=8), " \
		"SRV(t2, space=8) " \
	"), " \
	\
	"RootConstants(num32BitConstants=" HDR_PLUGIN_CONSTANTS_SIZE ", b3), " \
	"StaticSampler(s0, filter=FILTER_MIN_MAG_MIP_LINEAR, addressU=TEXTURE_ADDRESS_CLAMP, addressV=TEXTURE_ADDRESS_CLAMP, addressW=TEXTURE_ADDRESS_CLAMP, maxAnisotropy=1, comparisonFunc=COMPARISON_NEVER, space=8) "
