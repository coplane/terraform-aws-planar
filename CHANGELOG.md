# Changelog

## [0.9.0](https://github.com/coplane/planar-deploy-infra-aws/compare/v0.8.2...v0.9.0) (2026-08-12)


### Features

* Attach Bedrock Mantle policy ([#59](https://github.com/coplane/planar-deploy-infra-aws/issues/59)) ([52ffb7f](https://github.com/coplane/planar-deploy-infra-aws/commit/52ffb7fba2bad4a75be43b3e70a671cd880d58e5))

## [0.8.2](https://github.com/coplane/planar-deploy-infra-aws/compare/v0.8.1...v0.8.2) (2026-05-20)


### Bug Fixes

* override CrossSiteScripting_BODY and GenericRFI_BODY to Count in WAF common ruleset [CPLN-1099] ([#54](https://github.com/coplane/planar-deploy-infra-aws/issues/54)) ([370c196](https://github.com/coplane/planar-deploy-infra-aws/commit/370c196e2c338a549ac457bb0f246dd30f485422))

## [0.8.1](https://github.com/coplane/planar-deploy-infra-aws/compare/v0.8.0...v0.8.1) (2026-05-14)


### Bug Fixes

* ECR lifecycle policy with tag-aware retention ([#52](https://github.com/coplane/planar-deploy-infra-aws/issues/52)) ([b08da5a](https://github.com/coplane/planar-deploy-infra-aws/commit/b08da5a7cf35e59f4c35aa66a7f843299250b551))

## [0.8.0](https://github.com/coplane/planar-deploy-infra-aws/compare/v0.7.1...v0.8.0) (2026-05-04)


### Features

* expand ECS container metrics allowlist ([#48](https://github.com/coplane/planar-deploy-infra-aws/issues/48)) ([9507cfb](https://github.com/coplane/planar-deploy-infra-aws/commit/9507cfbc0bb840627f3855a7587b3226c81f7ead))

## [0.7.1](https://github.com/coplane/planar-deploy-infra-aws/compare/v0.7.0...v0.7.1) (2026-04-29)


### Bug Fixes

* split metrics pipelines + inline logs + isolate ECS exporter ([#46](https://github.com/coplane/planar-deploy-infra-aws/issues/46)) ([684c469](https://github.com/coplane/planar-deploy-infra-aws/commit/684c4697652ea1bcf200a6edab1a5b436dd85a1b))

## [0.7.0](https://github.com/coplane/planar-deploy-infra-aws/compare/v0.6.0...v0.7.0) (2026-04-29)


### Features

* add traces pipeline to OTel Collector sidecar [CPLN-1020] ([#43](https://github.com/coplane/planar-deploy-infra-aws/issues/43)) ([7030efe](https://github.com/coplane/planar-deploy-infra-aws/commit/7030efe8756b869944b9364ed6256ea5c607f1cc))

## [0.6.0](https://github.com/coplane/planar-deploy-infra-aws/compare/v0.5.1...v0.6.0) (2026-04-23)


### Features

* separate customer.name and service.name in OTel resource attributes [CPLN-1016]  ([#40](https://github.com/coplane/planar-deploy-infra-aws/issues/40)) ([19b9d1c](https://github.com/coplane/planar-deploy-infra-aws/commit/19b9d1ce35cd3144ceb2609a8f833e3ce12fc494))


### Bug Fixes

* protect custom secret from accidental deletion ([#41](https://github.com/coplane/planar-deploy-infra-aws/issues/41)) ([4b0c597](https://github.com/coplane/planar-deploy-infra-aws/commit/4b0c597c78da1ea2ce2a67f9d6807b1841d23a32))

## [0.5.1](https://github.com/coplane/planar-deploy-infra-aws/compare/v0.5.0...v0.5.1) (2026-04-23)


### Bug Fixes

* override SizeRestrictions_BODY to Count in WAF common ruleset ([#38](https://github.com/coplane/planar-deploy-infra-aws/issues/38)) ([00d133c](https://github.com/coplane/planar-deploy-infra-aws/commit/00d133c6ae20342738014bea7d41d65c77695719))

## [0.5.0](https://github.com/coplane/planar-deploy-infra-aws/compare/v0.4.1...v0.5.0) (2026-04-15)


### Features

* Add custom environment variables support for ECS task definition ([#34](https://github.com/coplane/planar-deploy-infra-aws/issues/34)) ([01ac6d5](https://github.com/coplane/planar-deploy-infra-aws/commit/01ac6d5cc4ba31766cbb9369903eeee981c9adf9))

## [0.4.1](https://github.com/coplane/planar-deploy-infra-aws/compare/v0.4.0...v0.4.1) (2026-04-02)


### Bug Fixes

* make Aurora engine version configurable ([#31](https://github.com/coplane/planar-deploy-infra-aws/issues/31)) ([be611e0](https://github.com/coplane/planar-deploy-infra-aws/commit/be611e0172386be210ca0d49844151b8abb8c0a5))

## [0.4.0](https://github.com/coplane/planar-deploy-infra-aws/compare/v0.3.0...v0.4.0) (2026-03-18)


### Features

* enable ECS deployment circuit breaker with rollback ([#27](https://github.com/coplane/planar-deploy-infra-aws/issues/27)) ([d565821](https://github.com/coplane/planar-deploy-infra-aws/commit/d5658215a88324619124c11d7b2e3a16b94b0a70))

## [0.3.0](https://github.com/coplane/planar-deploy-infra-aws/compare/v0.2.0...v0.3.0) (2026-03-09)


### Features

* add prevent_destroy to RDS, ALB, and S3 ([#25](https://github.com/coplane/planar-deploy-infra-aws/issues/25)) ([1138cba](https://github.com/coplane/planar-deploy-infra-aws/commit/1138cba86baddb58be960361cc22e936a49cc135))

## [0.2.0](https://github.com/coplane/planar-deploy-infra-aws/compare/v0.1.0...v0.2.0) (2026-03-06)


### Features

* add ignore_task_definition_changes toggle for external CI/CD deploys ([#22](https://github.com/coplane/planar-deploy-infra-aws/issues/22)) ([aa76608](https://github.com/coplane/planar-deploy-infra-aws/commit/aa76608ce198e59813cea9ce7d2f07198b4cb21f))

## 0.1.0 (2026-03-06)


### Features

* bootstrap release-please from ci baseline ([#20](https://github.com/coplane/planar-deploy-infra-aws/issues/20)) ([ca6e76f](https://github.com/coplane/planar-deploy-infra-aws/commit/ca6e76f83cbf9bf16e97ee1ad2aa805418111c41))
