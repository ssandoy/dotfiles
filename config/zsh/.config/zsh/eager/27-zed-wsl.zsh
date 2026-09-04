# Zed requires Vulkan, but Ubuntu's mesa-vulkan-drivers package ships no
# WSL-compatible (dzn/D3D12) ICD, so Zed only ever sees the llvmpipe software
# device and refuses to start without this override. Software rendering is
# noticeably slower but functional; scoped to WSL only.
if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  export ZED_ALLOW_EMULATED_GPU=1
fi
