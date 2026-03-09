---
trigger: always_on
glob: "**/*.go"
description: concise development rules
---

- **Prefer SDKs**: Always use native Go SDKs (Kind, Docker, Helm) over shell/exec.
- **Idempotency**: All logic MUST be idempotent.
- **TLS**: Use `superkind-ca` ClusterIssuer for all service certs.
- **Testing**: Include unit tests in the same package for all new features.
- **Registry**: Use `localhost:5001` or pull-through caches.
- **Go 1.24+**: Code must target Go 1.24+.
