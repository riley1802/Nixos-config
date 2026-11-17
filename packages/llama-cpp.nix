{ lib
, fetchFromGitHub
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
  buildCommit = "22c0ae1871b60123c5afc008a78fe9c6fffa2858";
in
effectiveStdenv.mkDerivation (finalAttrs: {
  pname = "llama-cpp";
  version = "0.7.0-dev";

  # XHToken fork is required for `--spec-type draft-dspark`; upstream v0.8.0
  # does not have it.
  # https://github.com/XHToken/llama.cpp/commit/22c0ae1871b60123c5afc008a78fe9c6fffa2858
  src = fetchFromGitHub {
    owner = "XHToken";
    repo = "llama.cpp";
    rev = buildCommit;
    hash = "sha256-IAm6EG0X8NQP+FPBaAzjmbD2eVzvwjSAFmA1C4nnHRA=";
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

  # GCC 14 + Werror: decode() uses std::all_of without #include <algorithm>.
  postPatch = ''
        substituteInPlace src/llama-context.cpp \
          --replace '#include <unordered_map>' '#include <algorithm>
    #include <unordered_map>'
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
    (cmakeFeature "LLAMA_BUILD_COMMIT" buildCommit)
  ];

  doCheck = false;

  meta = {
    description = "Inference of Meta's LLaMA model (and others) in pure C/C++";
    homepage = "https://github.com/XHToken/llama.cpp";
    license = lib.licenses.mit;
    mainProgram = "llama-server";
    platforms = [ "x86_64-linux" ];
  };
})
