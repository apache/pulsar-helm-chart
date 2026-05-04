# Keycloak

Keycloak is used to validate OIDC configuration.

To create the pulsar realm configuration, we use :

* `0-realm-pulsar-partial-export.json` : after creating pulsar realm in Keycloack UI, this file is the result of the partial export in Keycloak UI without options.
* `1-client-template.json` : this is the template to create pulsar clients.

To create the final `realm-pulsar.json`, merge files with `jq` command :

* create a client with `CLIENT_ID`, `CLIENT_SECRET` and `SUB_CLAIM_VALUE` :

```
CLIENT_ID=xx
CLIENT_SECRET=yy
SUB_CLAIM_VALUE=zz

jq -n --arg CLIENT_ID "$CLIENT_ID" --arg CLIENT_SECRET "$CLIENT_SECRET" --arg SUB_CLAIM_VALUE "$SUB_CLAIM_VALUE" 1-client-template.json > client.json
```

* then merge the realm and the client :

```
jq '.clients += [input]' 0-realm-pulsar-partial-export.json client.json > realm-pulsar.json
```
