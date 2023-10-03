#define ShaderRootSignature \
	"DescriptorTable(" \
		"SRV(t0, space=6), " \
		"SRV(t1, space=6), " \
		"SRV(t2, space=6), " \
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
	"DescriptorTable(" \
		"Sampler(s0, space=6, numDescriptors=10), " \
		"Sampler(s10, space=6, numDescriptors=2) " \
	"), " \
	\
	"SRV(t6, space=6), " \
	"CBV(b0, space=6), " \
	"CBV(b1, space=6), " \
	\
	"DescriptorTable(" \
		"SRV(t2, space=7), " \
		"SRV(t3, space=7), " \
		"SRV(t5, space=7), " \
		"SRV(t6, space=7), " \
		"UAV(u0, space=7), " \
		"UAV(u1, space=7), " \
		"UAV(u2, space=7), " \
		"UAV(u3, space=7), " \
		"SRV(t7, space=7, numDescriptors=12) " \
	"), " \
	\
	"SRV(t0, space=7), " \
	"SRV(t1, space=7), " \
	"SRV(t4, space=7), " \
	"CBV(b0, space=7), " \
	"CBV(b1, space=7), " \
	"CBV(b2, space=7), " \
	\
	"DescriptorTable(" \
		"SRV(t0, space=8), " \
		"UAV(u0, space=8) " \
	"), " \
	\
	"CBV(b0, space=8), " \
	"StaticSampler(s12, space=6), " \
	"StaticSampler(s13, space=6), " \
	"StaticSampler(s14, space=6), " \
	"StaticSampler(s15, space=6), " \
	"StaticSampler(s16, space=6), " \
	"StaticSampler(s17, space=6), " \
	"StaticSampler(s18, space=6), " \
	"StaticSampler(s19, space=6), " \
	"StaticSampler(s20, space=6), " \
	"StaticSampler(s21, space=6) "