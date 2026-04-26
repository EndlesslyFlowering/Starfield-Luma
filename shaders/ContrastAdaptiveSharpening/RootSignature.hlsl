#include "../shared.hlsl"

#define ShaderRootSignature \
	"RootFlags(0), " \
	\
	"DescriptorTable( " \
		"CBV(b0, space=2), " \
		"CBV(b1, space=2), " \
		"SRV(t0, space=2), " \
		"SRV(t1, space=2), " \
		"SRV(t2, space=2, flags=DATA_VOLATILE), " \
		"SRV(t3, space=2), " \
		"SRV(t4, space=2), " \
		"SRV(t5, space=2), " \
		"SRV(t6, space=2), " \
		"SRV(t7, space=2), " \
		"SRV(t8, space=2), " \
		"SRV(t9, space=2), " \
		"SRV(t10, space=2), " \
		"SRV(t11, space=2), " \
		"SRV(t12, space=2), " \
		"SRV(t13, space=2), " \
		"SRV(t14, space=2), " \
		"SRV(t15, space=2), " \
		"SRV(t16, space=2), " \
		"SRV(t17, space=2), " \
		"SRV(t18, space=2), " \
		"SRV(t19, space=2), " \
		"SRV(t20, space=2), " \
		"SRV(t21, space=2), " \
		"SRV(t22, space=2), " \
		"SRV(t23, space=2), " \
		"SRV(t24, space=2), " \
		"SRV(t25, space=2), " \
		"SRV(t26, space=2), " \
		"UAV(u0, space=2), " \
		"UAV(u1, space=2), " \
		"SRV(t27, space=2), " \
		"SRV(t28, space=2) " \
	"), " \
	\
	"DescriptorTable( " \
		"Sampler(s0, numDescriptors=10, space=2), " \
		"Sampler(s10, numDescriptors=2, space=2) " \
	"), " \
	\
	"DescriptorTable( " \
		"CBV(b0, space=3), " \
		"SRV(t0, space=3), " \
		"SRV(t1, space=3), " \
		"CBV(b1, space=3), " \
		"CBV(b2, space=3), " \
		"SRV(t2, space=3), " \
		"SRV(t3, space=3), " \
		"SRV(t4, space=3), " \
		"SRV(t5, space=3, flags=DATA_VOLATILE), " \
		"SRV(t6, space=3, flags=DATA_VOLATILE), " \
		"UAV(u0, space=3), " \
		"SRV(t7, space=3, flags=DATA_VOLATILE), " \
		"UAV(u1, space=3), " \
		"UAV(u2, space=3), " \
		"UAV(u3, space=3), " \
		"SRV(t8, numDescriptors=12, space=3, flags=DATA_VOLATILE) " \
	"), " \
	\
	"DescriptorTable( " \
		"SRV(t0, space=4), " \
		"UAV(u0, space=4), " \
		"CBV(b0, space=4) " \
	"), " \
	\
	"RootConstants(num32BitConstants=" HDR_PLUGIN_CONSTANTS_SIZE ", b3), " \
	"StaticSampler(s12, filter=FILTER_MIN_MAG_MIP_POINT, maxAnisotropy=1, comparisonFunc=COMPARISON_NEVER, space=2), " \
	"StaticSampler(s13, filter=FILTER_MIN_MAG_MIP_POINT, addressU=TEXTURE_ADDRESS_CLAMP, addressV=TEXTURE_ADDRESS_CLAMP, addressW=TEXTURE_ADDRESS_CLAMP, maxAnisotropy=1, comparisonFunc=COMPARISON_NEVER, space=2), " \
	"StaticSampler(s14, filter=FILTER_MIN_MAG_MIP_LINEAR, maxAnisotropy=1, comparisonFunc=COMPARISON_NEVER, space=2), " \
	"StaticSampler(s15, filter=FILTER_MIN_MAG_MIP_LINEAR, addressU=TEXTURE_ADDRESS_CLAMP, addressV=TEXTURE_ADDRESS_CLAMP, addressW=TEXTURE_ADDRESS_CLAMP, maxAnisotropy=1, comparisonFunc=COMPARISON_NEVER, space=2), " \
	"StaticSampler(s16, filter=FILTER_MIN_MAG_MIP_LINEAR, addressU=TEXTURE_ADDRESS_MIRROR, addressV=TEXTURE_ADDRESS_MIRROR, addressW=TEXTURE_ADDRESS_MIRROR, maxAnisotropy=1, comparisonFunc=COMPARISON_NEVER, space=2), " \
	"StaticSampler(s17, maxAnisotropy=4, comparisonFunc=COMPARISON_NEVER, space=2), " \
	"StaticSampler(s18, addressU=TEXTURE_ADDRESS_MIRROR, addressV=TEXTURE_ADDRESS_MIRROR, addressW=TEXTURE_ADDRESS_MIRROR, maxAnisotropy=4, comparisonFunc=COMPARISON_NEVER, space=2), " \
	"StaticSampler(s19, addressU=TEXTURE_ADDRESS_CLAMP, addressV=TEXTURE_ADDRESS_CLAMP, addressW=TEXTURE_ADDRESS_CLAMP, maxAnisotropy=4, comparisonFunc=COMPARISON_NEVER, space=2), " \
	"StaticSampler(s20, filter=FILTER_COMPARISON_MIN_MAG_MIP_LINEAR, addressU=TEXTURE_ADDRESS_CLAMP, addressV=TEXTURE_ADDRESS_CLAMP, addressW=TEXTURE_ADDRESS_CLAMP, maxAnisotropy=1, comparisonFunc=COMPARISON_LESS, space=2), " \
	"StaticSampler(s21, filter=FILTER_COMPARISON_MIN_MAG_MIP_LINEAR, addressU=TEXTURE_ADDRESS_CLAMP, addressV=TEXTURE_ADDRESS_CLAMP, addressW=TEXTURE_ADDRESS_CLAMP, maxAnisotropy=1, comparisonFunc=COMPARISON_GREATER, space=2) "