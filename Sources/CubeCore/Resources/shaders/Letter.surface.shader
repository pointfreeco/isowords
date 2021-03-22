#pragma arguments

float letterTextureSize;
texture2d<float, access::sample> lettersTexture;
float worldScale;

#pragma transparent
#pragma body

float sqrt2_2 = M_SQRT2_H / 2.0;
float size = 0.5 * worldScale;

int cubeX = max(0, min(int(floor((in.pos.x + size) / 2.0 / size * 3.0 - 0.01)), 2));
int cubeY = max(0, min(int(floor((in.pos.y + size) / 2.0 / size * 3.0 - 0.01)), 2));
int cubeZ = max(0, min(int(floor((in.pos.z + size) / 2.0 / size * 3.0 - 0.01)), 2));

int index = cubeX * 27 + cubeY * 9 + cubeZ * 3 + in.side;
float xIndex = float(index % 9);
float yIndex = float(index / 9);

float2 texcoord = _surface.diffuseTexcoord - float2(0.5, 0.5);
if (in.side == 2) {
  float x_ = texcoord.x * sqrt2_2 - texcoord.y * sqrt2_2;
  float y_ = texcoord.x * sqrt2_2 + texcoord.y * sqrt2_2;
  texcoord.x = x_;
  texcoord.y = y_;
}
texcoord = texcoord + float2(0.5, 0.5);

constexpr sampler lettersTextureSampler(coord::pixel);

float4 textureColor = lettersTexture.sample(
  lettersTextureSampler,
  float2(
    (texcoord.x + xIndex) * letterTextureSize,
    (texcoord.y + yIndex) * letterTextureSize
  )
);

_surface.diffuse.rgba = float4(0, 0, 0, textureColor.a);
