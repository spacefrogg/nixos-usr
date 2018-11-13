{ pkgs, config, version }:

with pkgs;

let
  lib = pkgs.lib;
  nixosDocPath = <nixpkgs/doc>;
  sources = lib.sourceFilesBySuffices ./. [ ".xml" ];

  modulesDoc = builtins.toFile "modules.xml" ''
    <section xmlns:xi="http://www.w3.org/2001/XInclude" id="modules">
    ${(lib.concatMapStrings (path: ''
      <xi:include href="${path}" />
    '') (lib.catAttrs "value" config.meta.doc))}
    </section>
  '';

  copySources = ''
    cp -prd $sources/* . # */
    cp -p ${nixosDocPath}/style.css .
    chmod -R u+w .
    echo "${version}" > version
  '';

in {
  manpages = runCommand "nixos-usr-manpages"
    { inherit sources;
      buildInputs = [ libxml2 libxslt ];
      allowedReferences = [ "out" ];
    }
    ''
      ${copySources}

      xmllint --noout --nonet --xinclude --noxincludenode \
        --relaxng ${docbook5}/xml/rng/docbook/docbook.rng \
        ./man-pages.xml

      mkdir -p $out/share/man $out/share/nixos-usr

      xsltproc --nonet --xinclude \
        --param man.output.in.separate.dir 1 \
        --param man.output.base.dir "'$out/share/man/'" \
        --param man.endnodes.are.numbered 0 \
        --param man.break.after.slash 1 \
        ${docbook5_xsl}/xml/xsl/docbook/manpages/docbook.xsl \
        ./man-pages.xml
    '';
}
