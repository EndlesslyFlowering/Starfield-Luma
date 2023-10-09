#define ShaderRootSignature \
	"RootFlags(ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT), " \
	\
	"DescriptorTable( " \
		"SRV(t0, space=8) " \
	"), " \
	\
	"DescriptorTable( " \
		"Sampler(s0, space=8) " \
	"), " \
	\
	"RootConstants(num32BitConstants=17, b3), "
