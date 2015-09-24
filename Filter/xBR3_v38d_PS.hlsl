/*
Hyllian's 2xBR v3.8d (squared) Shader

Copyright (C) 2011/2013 Hyllian/Jararaca - sergiogdb@gmail.com

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.


Incorporates some of the ideas from SABR shader. Thanks to Joshua Street.
*/

//code from https://github.com/libretro/common-shaders/blob/master/xbr/shaders/legacy/3xbr-v3.8d.cg


#include "../SpriteBatch.hlsli"

Texture2D<float4> Texture : register(t0);
sampler TextureSampler : register(s0);
const static float2 texture_size = float2(480.0, 320.0);  //size is the same as size in CreateDeviceDependentResources()


const static float coef = 2.0;
const static float4 eq_threshold = float4(15.0, 15.0, 15.0, 15.0);
const static float y_weight = 48.0;
const static float u_weight = 7.0;
const static float v_weight = 6.0;
const static float3x3 yuv = float3x3(0.299, 0.587, 0.114, -0.169, -0.331, 0.499, 0.499, -0.418, -0.0813);
const static float3x3 yuv_weighted = float3x3(y_weight*yuv[0], u_weight*yuv[1], v_weight*yuv[2]);
const static float scale = 3.0;
const static float4 delta = float4(1.0 / scale, 1.0 / scale, 1.0 / scale, 1.0 / scale);
const static float4 deltaL = float4(0.5 / scale, 1.0 / scale, 0.5 / scale, 1.0 / scale);
const static float4 deltaU = deltaL.yxwz;



float4 df(float4 A, float4 B)
{
	return abs(A - B);
}

float c_df(float3 c1, float3 c2) {
	float3 df = abs(c1 - c2);
	return df.r + df.g + df.b;
}


bool4 eq(float4 A, float4 B)
{
	return (df(A, B) < eq_threshold);
}

float4 weighted_distance(float4 a, float4 b, float4 c, float4 d, float4 e, float4 f, float4 g, float4 h)
{
	return (df(a, b) + df(a, c) + df(d, e) + df(d, f) + 4.0*df(g, h));
}




/*    FRAGMENT SHADER    */
float4 main(in PSIn VAR) : SV_TARGET0
{

	//<------ move from vertex shader in original code

	float2 ps = float2(1.0 / texture_size.x, 1.0 / texture_size.y);
	float dx = ps.x;
	float dy = ps.y;


	//    A1 B1 C1
	// A0  A  B  C C4
	// D0  D  E  F F4
	// G0  G  H  I I4
	//    G5 H5 I5

	// This line fix a bug in ATI cards.
	float2 texCoord = VAR.texcoord + float2(0.0000001, 0.0000001);

	float4 t1 = texCoord.xxxy + float4(-dx, 0, dx, -2.0*dy); // A1 B1 C1
	float4 t2 = texCoord.xxxy + float4(-dx, 0, dx, -dy); // A B C
	float4 t3 = texCoord.xxxy + float4(-dx, 0, dx, 0); // D E F
	float4 t4 = texCoord.xxxy + float4(-dx, 0, dx, dy); // G H I
	float4 t5 = texCoord.xxxy + float4(-dx, 0, dx, 2.0*dy); // G5 H5 I5
	float4 t6 = texCoord.xyyy + float4(-2.0*dx, -dy, 0, dy); // A0 D0 G0
	float4 t7 = texCoord.xyyy + float4(2.0*dx, -dy, 0, dy); // C4 F4 I4

	//------------->


	bool4 edr, edr_left, edr_up, px; // px = pixel, edr = edge detection rule
	bool4 interp_restriction_lv1, interp_restriction_lv2_left, interp_restriction_lv2_up;
	float4 fx, fx_left, fx_up, final_fx; // inequations of straight lines.
	float3 res1, res2, pix1, pix2;

	float2 fp = frac(texCoord*texture_size);

	float3 A1 = Texture.Sample(TextureSampler, t1.xw).rgb;
	float3 B1 = Texture.Sample(TextureSampler, t1.yw).rgb;
	float3 C1 = Texture.Sample(TextureSampler, t1.zw).rgb;

	float3 A = Texture.Sample(TextureSampler, t2.xw).rgb;
	float3 B = Texture.Sample(TextureSampler, t2.yw).rgb;
	float3 C = Texture.Sample(TextureSampler, t2.zw).rgb;

	float3 D = Texture.Sample(TextureSampler, t3.xw).rgb;
	float3 E = Texture.Sample(TextureSampler, t3.yw).rgb;
	float3 F = Texture.Sample(TextureSampler, t3.zw).rgb;

	float3 G = Texture.Sample(TextureSampler, t4.xw).rgb;
	float3 H = Texture.Sample(TextureSampler, t4.yw).rgb;
	float3 I = Texture.Sample(TextureSampler, t4.zw).rgb;

	float3 G5 = Texture.Sample(TextureSampler, t5.xw).rgb;
	float3 H5 = Texture.Sample(TextureSampler, t5.yw).rgb;
	float3 I5 = Texture.Sample(TextureSampler, t5.zw).rgb;

	float3 A0 = Texture.Sample(TextureSampler, t6.xy).rgb;
	float3 D0 = Texture.Sample(TextureSampler, t6.xz).rgb;
	float3 G0 = Texture.Sample(TextureSampler, t6.xw).rgb;

	float3 C4 = Texture.Sample(TextureSampler, t7.xy).rgb;
	float3 F4 = Texture.Sample(TextureSampler, t7.xz).rgb;
	float3 I4 = Texture.Sample(TextureSampler, t7.xw).rgb;


	float4 b = mul(float4x3(B, D, H, F), yuv_weighted[0]);
	float4 c = mul(float4x3(C, A, G, I), yuv_weighted[0]);
	float4 e = mul(float4x3(E, E, E, E), yuv_weighted[0]);
	float4 d = b.yzwx;
	float4 f = b.wxyz;
	float4 g = c.zwxy;
	float4 h = b.zwxy;
	float4 i = c.wxyz;

	float4 i4 = mul(float4x3(I4, C1, A0, G5), yuv_weighted[0]);
	float4 i5 = mul(float4x3(I5, C4, A1, G0), yuv_weighted[0]);
	float4 h5 = mul(float4x3(H5, F4, B1, D0), yuv_weighted[0]);
	float4 f4 = h5.yzwx;

	float4 c1 = i4.yzwx;
	float4 g0 = i5.wxyz;

	float4 Ao = float4(1.0, -1.0, -1.0, 1.0);
	float4 Bo = float4(1.0, 1.0, -1.0, -1.0);
	float4 Co = float4(1.5, 0.5, -0.5, 0.5);
	float4 Ax = float4(1.0, -1.0, -1.0, 1.0);
	float4 Bx = float4(0.5, 2.0, -0.5, -2.0);
	float4 Cx = float4(1.0, 1.0, -0.5, 0.0);
	float4 Ay = float4(1.0, -1.0, -1.0, 1.0);
	float4 By = float4(2.0, 0.5, -2.0, -0.5);
	float4 Cy = float4(2.0, 0.0, -1.0, 0.5);

	// These inequations define the line below which interpolation occurs.
	fx = (Ao*fp.y + Bo*fp.x);
	fx_left = (Ax*fp.y + Bx*fp.x);
	fx_up = (Ay*fp.y + By*fp.x);

	interp_restriction_lv1 = ((e != f) && (e != h) && (!eq(f, b) && !eq(h, d) || eq(e, i) && !eq(f, i4) && !eq(h, i5) || eq(e, g) || eq(e, c)) && (f != f4 && f != i || h != h5 && h != i || h != g || f != c || eq(b, c1) && eq(d, g0)));
	interp_restriction_lv2_left = ((e != g) && (d != g));
	interp_restriction_lv2_up = ((e != c) && (b != c));

	float4 fx45 = saturate((fx + delta - Co) / (2 * delta));
	float4 fx30 = saturate((fx_left + deltaL - Cx) / (2 * deltaL));
	float4 fx60 = saturate((fx_up + deltaU - Cy) / (2 * deltaU));

	//	float4 fx45 = max(0, min(1, (fx      + delta -Co)/(2*delta)));
	//	float4 fx30 = max(0, min(1, (fx_left + delta -Cx)/(2*delta)));
	//	float4 fx60 = max(0, min(1, (fx_up   + delta -Cy)/(2*delta)));

	//	float4 fx45 = smoothstep(Co - delta, Co + delta, fx);
	//	float4 fx30 = smoothstep(Cx - delta, Cx + delta, fx_left);
	//	float4 fx60 = smoothstep(Cy - delta, Cy + delta, fx_up);


	edr = (weighted_distance(e, c, g, i, h5, f4, h, f) < weighted_distance(h, d, i5, f, i4, b, e, i)) && interp_restriction_lv1;
	edr_left = ((coef*df(f, g)) <= df(h, c)) && interp_restriction_lv2_left && edr;
	edr_up = (df(f, g) >= (coef*df(h, c))) && interp_restriction_lv2_up && edr;


	fx45 = edr*fx45;
	fx30 = edr_left*fx30;
	fx60 = edr_up*fx60;

	px = (df(e, f) <= df(e, h));

	float4 maximo = max(max(fx30, fx60), fx45);

	float4x3 pix = float4x3(lerp(E, lerp(H, F, px.x), maximo.x), lerp(E, lerp(F, B, px.y), maximo.y), lerp(E, lerp(B, D, px.z), maximo.z), lerp(E, lerp(D, H, px.w), maximo.w));
	float4 pixel = mul(pix, yuv_weighted[0]);


	float4 diff = df(pixel, e);

	float3 res = pix[0];
	float mx = diff.x;

	if (diff.y > mx) { res = pix[1]; mx = diff.y; }
	if (diff.z > mx) { res = pix[2]; mx = diff.z; }
	if (diff.w > mx) { res = pix[3]; }

	return float4(res, 1.0);

}