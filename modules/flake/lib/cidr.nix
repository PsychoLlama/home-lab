{ lib, ... }:

let
  /**
    Two raised to a non-negative power. Stands in for a bit shift, which Nix
    lacks.

    # Type

    ```
    pow2 :: Int -> Int
    ```
  */
  pow2 = n: if n == 0 then 1 else 2 * pow2 (n - 1);

  /**
    Split `str` on `separator`, expecting exactly `count` parts.

    # Inputs

    `name`
    : What the parts are, for error messages.

    # Type

    ```
    splitExactly :: { name :: String, separator :: String, count :: Int } -> String -> [String]
    ```
  */
  splitExactly =
    {
      name,
      separator,
      count,
    }:
    str:

    let
      parts = lib.splitString separator str;
      found = lib.length parts;
    in

    lib.throwIfNot (found == count)
      "expected ${toString count} ${name} separated by '${separator}', found ${toString found} in '${str}'"
      parts;

  /**
    Parse a bounded decimal number. Rejects signs, whitespace, and leading
    zeros.

    # Inputs

    `name`
    : What the number is, for error messages.

    `max`
    : Largest accepted value (inclusive).

    # Type

    ```
    parseDecimal :: { name :: String, max :: Int } -> String -> Int
    ```
  */
  parseDecimal =
    { name, max }:
    str:

    let
      isDecimal = lib.match "0|[1-9][0-9]*" str != null;

      # Checking length first keeps absurdly long input from overflowing.
      inRange = lib.stringLength str <= lib.stringLength (toString max) && lib.toInt str <= max;
    in

    lib.throwIfNot isDecimal "invalid ${name} '${str}': expected a decimal number without leading zeros"
      (lib.throwIfNot inRange "${name} ${str} is out of range (0-${toString max})" (lib.toInt str));

  /**
    Parse a dotted-quad IPv4 address into a 32-bit integer.

    # Type

    ```
    parseAddress :: String -> Int
    ```
  */
  parseAddress =
    str:
    lib.pipe str [
      (splitExactly {
        name = "octets";
        separator = ".";
        count = 4;
      })
      (map (parseDecimal {
        name = "octet";
        max = 255;
      }))
      (lib.foldl' (acc: octet: acc * 256 + octet) 0)
    ];

  /**
    Parse a prefix length, the part after the slash.

    # Type

    ```
    parsePrefixLength :: String -> Int
    ```
  */
  parsePrefixLength = parseDecimal {
    name = "prefix length";
    max = 32;
  };

  /**
    Format a 32-bit integer as a dotted-quad IPv4 address.

    # Type

    ```
    formatAddress :: Int -> String
    ```
  */
  formatAddress =
    int:
    lib.concatMapStringsSep "." (shift: toString (lib.bitAnd 255 (int / pow2 shift))) [
      24
      16
      8
      0
    ];

  /**
    Parse CIDR notation into an address and prefix length.

    # Type

    ```
    parseCidr :: String -> { address :: Int, prefixLength :: Int }
    ```
  */
  parseCidr =
    str:

    let
      parts = splitExactly {
        name = "parts";
        separator = "/";
        count = 2;
      } str;

      parsed = {
        address = parseAddress (lib.elemAt parts 0);
        prefixLength = parsePrefixLength (lib.elemAt parts 1);
      };
    in

    # Validate every field now. Left lazy, reading one field would skip
    # validating the others, and errors would surface outside `parse`'s
    # error context.
    lib.deepSeq parsed parsed;

  /**
    Derive the subnet an address belongs to.

    # Type

    ```
    describeSubnet :: { address :: Int, prefixLength :: Int } -> Subnet
    ```
  */
  describeSubnet =
    { address, prefixLength }:

    let
      hostMask = pow2 (32 - prefixLength) - 1;
      subnetMask = lib.bitXor (pow2 32 - 1) hostMask;
      network = lib.bitAnd address subnetMask;
    in

    {
      subnet = {
        cidr = "${formatAddress network}/${toString prefixLength}";
        mask = formatAddress subnetMask;
        inherit prefixLength;
      };

      addresses = {
        host = formatAddress address;
        network = formatAddress network;
        broadcast = formatAddress (lib.bitOr network hostMask);
      };
    };

  /**
    Parse an IPv4 address with a prefix length, like `10.0.1.1/24`, and
    describe the subnet around it.

    The address is four decimal octets (0-255) separated by dots, and the
    prefix length is a decimal number (0-32) after a slash. Both are
    required. Leading zeros, whitespace, and netmask-style prefixes
    (`/255.255.255.0`) are rejected. The address may have host bits set;
    they're kept in `addresses.host` and cleared everywhere else.

    Throws on malformed input.

    # Example

    ```nix
    parseV4 "10.0.1.1/24"
    => {
      subnet = {
        cidr = "10.0.1.0/24";
        mask = "255.255.255.0";
        prefixLength = 24;
      };

      addresses = {
        host = "10.0.1.1";
        network = "10.0.1.0";
        broadcast = "10.0.1.255";
      };
    }
    ```

    # Type

    ```
    parseV4 :: String -> Subnet

    Subnet :: {
      subnet :: { cidr :: String, mask :: String, prefixLength :: Int },
      addresses :: { host :: String, network :: String, broadcast :: String },
    }
    ```
  */
  parseV4 =
    cidr:
    lib.addErrorContext "while parsing IPv4 CIDR '${cidr}'" (
      lib.pipe cidr [
        parseCidr
        describeSubnet
      ]
    );
in

{
  flake.lib.cidr.v4.parse = parseV4;
}
