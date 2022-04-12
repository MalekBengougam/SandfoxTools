#version 120

varying vec2 v_UV;
uniform vec4 u_LineColor;

uniform sampler2D u_Texture;

void main(void)
{
	vec4 texColor = texture2D(u_Texture, v_UV);

	gl_FragColor = u_LineColor * texColor;
}