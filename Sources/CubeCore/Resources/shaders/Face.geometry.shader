#pragma arguments

#pragma varyings
float3 pos;
int side = -1;

#pragma transparent
#pragma body

out.pos = (scn_node.modelTransform * _geometry.position).xyz;

float3 normal = (scn_node.inverseModelTransform * float4(_geometry.normal, 0)).xyz;

if (abs(dot(normal, float3(0, 0, 1))) >= 0.98) {
  out.side = 0; // left
} else if (abs(dot(normal, float3(1, 0, 0))) >= 0.98) {
  out.side = 1; // right
} else if (abs(dot(normal, float3(0, 1, 0))) >= 0.98) {
  out.side = 2; // top
}
