# Keycloak

Keycloak is used to validate OIDC configuration.

To create the pulsar realm configuration, we use :

* `0-realm-pulsar-partial-export.json` : after creating pulsar realm in Keycloack UI, this file is the result of the partial export in Keycloak UI without options.
* `1-clientscope-nbf.json` : Keycloak does not include the `nbf` claim (not-before) in the JWT token. This is the client scope to add to pulsar clients.
* `2-client-template.json` : this is the template to create pulsar clients.

To create the final `realm-pulsar.json`, merge files with `jq` command :

* to merge the partial export and the client scope nbf :

```
jq '.clientScopes += [input]' 0-realm-pulsar-partial-export.json 1-clientscope-nbf.json > realm-pulsar-with-clientscopes.json
```

* then to create a client with `CLIENT_ID` and `CLIENT_SECRET` :

```
CLIENT_ID=xx
CLIENT_SECRET=yy

jq -n --arg CLIENT_ID "$CLIENT_ID" --arg CLIENT_SECRET "$CLIENT_SECRET" 2-client-template.json > client.json
```

* finally merge the realm and the client :

```
jq '.clients += [input]' realm-pulsar-with-clientscopes.json client.json > realm-pulsar.json
```
