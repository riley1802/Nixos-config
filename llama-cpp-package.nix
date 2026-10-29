{ lib
, fetchFromGitHub
, fetchurl
, cmake
, ninja
, pkg-config
, openssl
, autoAddDriverRunpath
, cudaPackages
,
}:

let
  # CUDA needs the toolkit's stdenv, or the result fails to link libstdc++.
  # https://github.com/NixOS/nixpkgs/blob/6713828a351efa628b025a1adf7f43cbf8597513/pkgs/by-name/ll/llama-cpp/package.nix
  effectiveStdenv = cudaPackages.backendStdenv;
  inherit (lib) cmakeBool cmakeFeature;
in
effectiveStdenv.mkDerivation (finalAttrs: {
  pname = "llama-cpp";
  version = "0.8.0";

  # LFM3 (text, vision, audio, omni) landed in v0.8.0 / b11960. nixos-26.05
  # still packages build 9190, which cannot load these GGUFs.
  # https://github.com/ggml-org/llama.cpp/releases/tag/v0.8.0
  src = fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    tag = "v${finalAttrs.version}";
    hash = "sha256-WQAtD8Hos6fEtgPQId7nZiLGyP4asAMKJYEXZid1nqc=";
  };

  # v0.8.0 embeds the web UI from a release tarball. Building tools/ui here
  # would compile Storybook, Playwright, and sharp for a UI the release
  # already publishes.
  # https://github.com/ggml-org/llama.cpp/blob/v0.8.0/scripts/ui-assets.cmake
  uiDist = fetchurl {
    url = "https://huggingface.co/buckets/ggml-org/llama-ui/resolve/b11960/dist.tar.gz";
    hash = "sha256-7cawX/JiH18IzuTnnPi+sCgF8hiId2NU3R3c+fwmCeg=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    cudaPackages.cuda_nvcc
    autoAddDriverRunpath
  ];

  # cuda_cccl provides <nv/target>, which the CUDA backend includes directly.
  buildInputs = [
    openssl
    cudaPackages.cuda_cccl
    cudaPackages.cuda_cudart
    cudaPackages.libcublas
  ];

  preConfigure = ''
    mkdir -p tools/ui/dist
    tar -xzf ${finalAttrs.uiDist} -C tools/ui/dist
    test -f tools/ui/dist/index.html
  '';

  cmakeFlags = [
    # -march=native would bake this machine into the binary and make the
    # build unreproducible. The CPU variants below pick AVX2 at runtime.
    (cmakeBool "GGML_NATIVE" false)
    (cmakeBool "GGML_CPU_ALL_VARIANTS" true)
    (cmakeBool "GGML_BACKEND_DL" true)
    (cmakeFeature "GGML_BACKEND_DIR" "${placeholder "out"}/bin")

    # This PC has a Turing 1660 SUPER (7.5) and an Ampere 3050 (8.6).
    # Compiling every architecture nixpkgs would default to is most of
    # the CUDA build time, and nothing else here can use those cubins.
    (cmakeBool "GGML_CUDA" true)
    (cmakeBool "GGML_CUDA_NCCL" false)
    (cmakeFeature "CMAKE_CUDA_ARCHITECTURES" "75;86")

    (cmakeBool "LLAMA_BUILD_EXAMPLES" false)
    (cmakeBool "LLAMA_BUILD_SERVER" true)
    (cmakeBool "LLAMA_BUILD_TOOLS" true)
    (cmakeBool "LLAMA_BUILD_TESTS" false)
    (cmakeBool "LLAMA_BUILD_UI" false)
    (cmakeBool "LLAMA_USE_PREBUILT_UI" false)
    (cmakeBool "LLAMA_BUILD_IS_DEV" false)
    (cmakeBool "LLAMA_OPENSSL" true)
    (cmakeBool "BUILD_SHARED_LIBS" true)
    (cmakeFeature "LLAMA_BUILD_NUMBER" "11960")
    (cmakeFeature "LLAMA_BUILD_COMMIT" "8642541")
  ];

  doCheck = false;

  meta = {
    description = "Inference of Meta's LLaMA model (and others) in pure C/C++";
    homepage = "https://github.com/ggml-org/llama.cpp";
    license = lib.licenses.mit;
    mainProgram = "llama-server";
    platforms = [ "x86_64-linux" ];
  };
})
