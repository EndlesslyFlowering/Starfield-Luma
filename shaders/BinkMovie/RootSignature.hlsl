#define ShaderRootSignature \
	"RootFlags(ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT), " \
	"DescriptorTable(" \
		"SRV(t0, space=8), " \
		"SRV(t1, space=8), " \
		"SRV(t2, space=8) " \
	"), " \
	\
	"StaticSampler(s0, space=8) "