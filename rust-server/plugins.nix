{ pkgs }:

[
  {
    name = "Backpacks.cs";
    license = "MIT";
    revision = "9fb6dc3ed5f0047f4f5d5b1dc2c304687caf0dfb";
    source = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/WheteThunger/Backpacks/9fb6dc3ed5f0047f4f5d5b1dc2c304687caf0dfb/Backpacks.cs";
      hash = "sha256-dRTEqRAYwXEuIlZlitQIuHSgPtYQsbVMcPVhFcPll9s=";
    };
  }
  {
    name = "RemoverTool.cs";
    license = "MIT";
    revision = "1d2560f2b5a5da66d4290844004f8458e55339f8";
    source = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/MONaH-Rasta/RemoverTool/1d2560f2b5a5da66d4290844004f8458e55339f8/RemoverTool.cs";
      hash = "sha256-3pHs3F3gzUHDWvpG0niHwXsdRrjaduIh3q0Q+KGps/w=";
    };
  }
  {
    name = "RecycleManager.cs";
    license = "MIT";
    revision = "ec87509dfbe24d6ca8a3ee59df2920d4ad931d74";
    source = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/WheteThunger/RecycleManager/ec87509dfbe24d6ca8a3ee59df2920d4ad931d74/RecycleManager.cs";
      hash = "sha256-ggjCvctwlndff7ZtIrrMsoyZPcHT0SNzataGVBlNyO4=";
    };
  }
]
