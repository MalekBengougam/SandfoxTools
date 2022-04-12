#version 120

uniform sampler2D u_Texture;

varying vec2 v_UV;

void main(void)
{
	gl_FragColor = texture2D(u_Texture, v_UV);
}