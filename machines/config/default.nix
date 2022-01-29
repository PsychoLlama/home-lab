{
  domain = "selfhosted.city";
  datacenter = "lab";
  certificates = map builtins.readFile [ ./certificate.pem ];
}
