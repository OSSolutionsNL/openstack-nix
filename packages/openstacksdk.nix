{
  keystoneauth1,
  python3Packages,
}:
let
  inherit (python3Packages)
    platformdirs
    cryptography
    dogpile-cache
    jmespath
    jsonpatch
    munch
    netifaces
    openstackdocstheme
    os-service-types
    pbr
    pythonOlder
    pyyaml
    requestsexceptions
    setuptools
    sphinxHook
    ;
in
python3Packages.buildPythonPackage rec {
  pname = "openstacksdk";
  version = "4.0.0";
  pyproject = true;

  disabled = pythonOlder "3.8";

  outputs = [
    "out"
    "man"
  ];

  src = python3Packages.fetchPypi {
    inherit pname version;
    hash = "sha256-54YN2WtwUxMJI8EdVx0lgCuWjx4xOIRct8rHxrMzv0s=";
  };

  postPatch = ''
    # Disable rsvgconverter not needed to build manpage
    substituteInPlace doc/source/conf.py \
      --replace-fail "'sphinxcontrib.rsvgconverter'," "#'sphinxcontrib.rsvgconverter',"
  '';

  nativeBuildInputs = [
    openstackdocstheme
    sphinxHook
  ];

  sphinxBuilders = [ "man" ];

  build-system = [ setuptools ];

  dependencies = [
    platformdirs
    cryptography
    dogpile-cache
    jmespath
    jsonpatch
    keystoneauth1
    munch
    netifaces
    os-service-types
    pbr
    requestsexceptions
    pyyaml
  ];

  # Checks moved to 'passthru.tests' to workaround slowness
  doCheck = false;

  #passthru.tests = {
  #  tests = callPackage ./tests.nix { };
  #};

  pythonImportsCheck = [ "openstack" ];
}
