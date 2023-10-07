#define ShaderRootSignature \
	"RootFlags(ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT), " \
	\
	"DescriptorTable( " \
		"SRV(t0, space=8), " \
		"SRV(t1, space=8), " \
		"SRV(t2, space=8) " \
	"), " \
	\
	"RootConstants(num32BitConstants=10, b3), " \
	"StaticSampler(s0, filter=FILTER_MIN_MAG_MIP_LINEAR, addressU=TEXTURE_ADDRESS_CLAMP, addressV=TEXTURE_ADDRESS_CLAMP, addressW=TEXTURE_ADDRESS_CLAMP, maxAnisotropy=1, comparisonFunc=COMPARISON_NEVER, space=8) "