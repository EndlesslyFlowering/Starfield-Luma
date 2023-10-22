#include "RootSignature.hlsl"

cbuffer _18_20 : register(b0, space7)
{
	float4 _20_m0[3269] : packoffset(c0);
};

cbuffer _23_25 : register(b0, space8)
{
	float4 _25_m0[894] : packoffset(c0);
};

struct SpriteDataType
{
	float4 f4_0;
	float3 f3_0;
	uint  u0;
	uint  u1;
	float f0;
	uint  u2;
	float f1;
	float f2;
	float f3;
	int   i0;
	int   i1;
};

cbuffer _28_30 : register(b1, space8)
{
	SpriteDataType SpriteData : packoffset(c0);
};

StructuredBuffer<float>  _13      : register(t0, space8);
StructuredBuffer<float4> _14      : register(t1, space8);
SamplerState             Sampler0 : register(s0, space8);

static float4 TEXCOORD;
static float4 SV_Target;

struct SPIRV_Cross_Input
{
	float4 TEXCOORD : TEXCOORD0;
};

struct SPIRV_Cross_Output
{
	float4 SV_Target : SV_Target0;
};

void frag_main()
{
	uint _57 = SpriteData.u0;
	uint _56 = SpriteData.u1;

	uint textureHeapIndex = SpriteData.u2;

	float _60 = _13.Load(_56).x;

	float2 _64 = TEXCOORD.xy;

	if ((_57 & 2) != 0)
	{
		float _130 = _60 + 0.001f;
		_64 = ((_64 - 0.5f) / _130) + 0.5f;
	}

	Texture2D<float4> texHandle = ResourceDescriptorHeap[textureHeapIndex];
	float3 _116 = texHandle.Sample(Sampler0, _64).rgb;

	uint heapTextureWidth;
	uint heapTextureHeight;

	texHandle.GetDimensions(heapTextureWidth,
	                        heapTextureHeight);

	float3 testIfSun = texHandle.Load(int3(127, 127, 0)).rgb;

	if (heapTextureWidth == 256
	 && all(testIfSun == 1.f)) // sun texture is 256x256 and the middle is RGB(1,1,1)
	{
		// values have been tuned so that the sun has a blurry outer line that is not too defined
		// targets 80000+ nits for the sun so that it is the brightest part of the image
		// so that the tone mapper doesn't decrease it
		// with targeting 100000+ nits making the outer line blurry is harder
		// 80000 nits seems to be a good choice

		// only increase the bright parts of the texture
		// after 3 slight banding starts appearing
		_116 = _116 * _116 * _116;
		// 400 gives 80000+ nits for when the sun is pure white (for example noon)
		_116 *= 400.f;
	}

	float3 _158;

	if (_56 == asuint(_25_m0[1]).z)
	{
		_158 = _14.Load(0).rgb;
	}
	else
	{
		uint _151 = _56 + 514;
		_158 = _25_m0[_151].rgb;
	}
	float _164 = (1.f - ((1.f - saturate((SpriteData.f3 + log2(min(max((_20_m0[316u].y > 1e-10f) ? _20_m0[316u].y : (_20_m0[316u].z / max(_20_m0[316u].x * 1.2f, 0.000099999999f)), _20_m0[317u].y), _20_m0[317u].z) * 1.2f)) / (SpriteData.f3 - SpriteData.f2))) * SpriteData.f1)) * _60;

	float3 o = ((_164 * _116) * _158) * SpriteData.f3_0.rgb;

	SV_Target.rgb = ((_164 * _116) * _158) * SpriteData.f3_0.rgb;
	SV_Target.a = 0.f;
}

[RootSignature(ShaderRootSignature)]
[earlydepthstencil]
SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
	TEXCOORD = stage_input.TEXCOORD;
	frag_main();
	SPIRV_Cross_Output stage_output;
	stage_output.SV_Target = SV_Target;
	return stage_output;
}
