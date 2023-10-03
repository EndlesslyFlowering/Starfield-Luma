#define ShaderRootSignature \
	"RootFlags(ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT), " \
	"RootConstants(num32BitConstants=3, b0), " \
	\
	"DescriptorTable(" \
		"SRV(t0, space=8)" \
	"), " \
	\
	"StaticSampler(s0, space=8) "