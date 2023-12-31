#include "../shared.hlsl"

#define ShaderRootSignature \
	"RootFlags(ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT), " \
	\
	"RootConstants(num32BitConstants=3, b0), " \
	\
	"DescriptorTable( " \
		"SRV(t0, space=6), " \
		"SRV(t1, space=6), " \
		"SRV(t2, space=6, flags=DATA_VOLATILE), " \
		"SRV(t3, space=6), " \
		"SRV(t4, space=6), " \
		"SRV(t5, space=6), " \
		"SRV(t7, space=6), " \
		"SRV(t8, space=6), " \
		"SRV(t9, space=6), " \
		"SRV(t10, space=6), " \
		"SRV(t11, space=6), " \
		"SRV(t12, space=6), " \
		"SRV(t13, space=6), " \
		"SRV(t14, space=6), " \
		"SRV(t15, space=6), " \
		"SRV(t16, space=6), " \
		"SRV(t17, space=6), " \
		"SRV(t18, space=6), " \
		"SRV(t19, space=6), " \
		"SRV(t20, space=6), " \
		"SRV(t21, space=6), " \
		"SRV(t22, space=6), " \
		"SRV(t23, space=6), " \
		"SRV(t24, space=6), " \
		"SRV(t25, space=6), " \
		"SRV(t26, space=6), " \
		"UAV(u0, space=6), " \
		"UAV(u1, space=6), " \
		"SRV(t27, space=6), " \
		"SRV(t28, space=6) " \
	"), " \
	\
	"DescriptorTable( " \
		"Sampler(s0, numDescriptors=10, space=6), " \
		"Sampler(s10, numDescriptors=2, space=6) " \
	"), " \
	\
	"SRV(t6, space=6), " \
	"CBV(b0, space=6), " \
	"CBV(b1, space=6), " \
	\
	"DescriptorTable( " \
		"SRV(t2, space=7), " \
		"SRV(t3, space=7), " \
		"SRV(t5, space=7, flags=DATA_VOLATILE), " \
		"SRV(t6, space=7, flags=DATA_VOLATILE), " \
		"UAV(u0, space=7), " \
		"SRV(t7, space=7, flags=DATA_VOLATILE), " \
		"UAV(u1, space=7), " \
		"UAV(u2, space=7), " \
		"UAV(u3, space=7), " \
		"SRV(t8, numDescriptors=12, space=7, flags=DATA_VOLATILE) " \
	"), " \
	\
	"SRV(t0, space=7), " \
	"SRV(t1, space=7), " \
	"SRV(t4, space=7), " \
	"CBV(b0, space=7), " \
	"CBV(b1, space=7), " \
	"CBV(b2, space=7), " \
	\
	"DescriptorTable( " \
		"SRV(t0, space=9), " \
		"SRV(t1, space=9), " \
		"SRV(t2, space=9), " \
		"SRV(t3, space=9), " \
		"SRV(t4, space=9) " \
	"), " \
	\
	"RootConstants(num32BitConstants=" HDR_PLUGIN_CONSTANTS_SIZE ", b3), " \
	"StaticSampler(s12, filter=FILTER_MIN_MAG_MIP_POINT, maxAnisotropy=1, comparisonFunc=COMPARISON_NEVER, space=6), " \
	"StaticSampler(s13, filter=FILTER_MIN_MAG_MIP_POINT, addressU=TEXTURE_ADDRESS_CLAMP, addressV=TEXTURE_ADDRESS_CLAMP, addressW=TEXTURE_ADDRESS_CLAMP, maxAnisotropy=1, comparisonFunc=COMPARISON_NEVER, space=6), " \
	"StaticSampler(s14, filter=FILTER_MIN_MAG_MIP_LINEAR, maxAnisotropy=1, comparisonFunc=COMPARISON_NEVER, space=6), " \
	"StaticSampler(s15, filter=FILTER_MIN_MAG_MIP_LINEAR, addressU=TEXTURE_ADDRESS_CLAMP, addressV=TEXTURE_ADDRESS_CLAMP, addressW=TEXTURE_ADDRESS_CLAMP, maxAnisotropy=1, comparisonFunc=COMPARISON_NEVER, space=6), " \
	"StaticSampler(s16, filter=FILTER_MIN_MAG_MIP_LINEAR, addressU=TEXTURE_ADDRESS_MIRROR, addressV=TEXTURE_ADDRESS_MIRROR, addressW=TEXTURE_ADDRESS_MIRROR, maxAnisotropy=1, comparisonFunc=COMPARISON_NEVER, space=6), " \
	"StaticSampler(s17, maxAnisotropy=4, comparisonFunc=COMPARISON_NEVER, space=6), " \
	"StaticSampler(s18, addressU=TEXTURE_ADDRESS_MIRROR, addressV=TEXTURE_ADDRESS_MIRROR, addressW=TEXTURE_ADDRESS_MIRROR, maxAnisotropy=4, comparisonFunc=COMPARISON_NEVER, space=6), " \
	"StaticSampler(s19, addressU=TEXTURE_ADDRESS_CLAMP, addressV=TEXTURE_ADDRESS_CLAMP, addressW=TEXTURE_ADDRESS_CLAMP, maxAnisotropy=4, comparisonFunc=COMPARISON_NEVER, space=6), " \
	"StaticSampler(s20, filter=FILTER_COMPARISON_MIN_MAG_MIP_LINEAR, addressU=TEXTURE_ADDRESS_CLAMP, addressV=TEXTURE_ADDRESS_CLAMP, addressW=TEXTURE_ADDRESS_CLAMP, maxAnisotropy=1, comparisonFunc=COMPARISON_LESS, space=6), " \
	"StaticSampler(s21, filter=FILTER_COMPARISON_MIN_MAG_MIP_LINEAR, addressU=TEXTURE_ADDRESS_CLAMP, addressV=TEXTURE_ADDRESS_CLAMP, addressW=TEXTURE_ADDRESS_CLAMP, maxAnisotropy=1, comparisonFunc=COMPARISON_GREATER, space=6), " \
	"StaticSampler(s0, filter=FILTER_MIN_MAG_MIP_LINEAR, addressU=TEXTURE_ADDRESS_CLAMP, addressV=TEXTURE_ADDRESS_CLAMP, addressW=TEXTURE_ADDRESS_CLAMP, maxAnisotropy=1, comparisonFunc=COMPARISON_NEVER, space=9) "
