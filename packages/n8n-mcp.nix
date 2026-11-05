# n8n with MCP-visible node definitions retained for workflow construction.
{ coreutils
, findutils
, n8n
, runCommand
,
}:
runCommand "${n8n.name}-mcp-node-types"
{
  nativeBuildInputs = [
    coreutils
    findutils
  ];
  inherit (n8n) meta;
  passthru = n8n.passthru or { };
}
  ''
    cp -a --reflink=auto ${n8n}/. "$out/"

    # The installed launcher contains the original output path. Point it at
    # this copy so Node resolves packages containing the compatibility links.
    chmod u+w "$out/bin/n8n"
    substituteInPlace "$out/bin/n8n" \
      --replace-fail '${n8n}' "$out"

    # n8n's generator emitted runtime schemas but its MCP resolver in 2.34.6
    # looks only for the corresponding .ts names. A relative link preserves
    # one canonical generated file while satisfying both consumers.
    find "$out/lib/n8n" \
      -type d \
      -path "*/dist/node-definitions*" \
      -exec chmod u+w {} +
    while IFS= read -r -d "" source; do
      target="''${source%.schema.js}.ts"
      ln -s "$(basename "$source")" "$target"
    done < <(
      find "$out/lib/n8n" \
        -type f \
        -path "*/dist/node-definitions/*" \
        -name "*.schema.js" \
        -print0
    )
  ''
