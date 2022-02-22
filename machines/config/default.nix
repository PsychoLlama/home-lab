{
  domain = "selfhosted.city";
  datacenter = "lab";
  certificates = map builtins.readFile [ ./certificate.pem ];
  contactEmail = "JesseTheGibson+lab@gmail.com"; # Used for LetsEncrypt.
}
