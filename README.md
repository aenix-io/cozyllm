# CozyLLM

AI application catalogs for [Cozystack](https://cozystack.io), hosted by [Ænix](https://aenix.io). Model serving, API gateways, notebooks, visual pipelines, image generation, SRE assistance — plus workflow automation and a chat UI — deployed into your Cozystack cluster through the dashboard.

> **Not part of the Cozystack project and not part of the CNCF.** Cozystack is a CNCF Sandbox project; nothing here is endorsed by, released by, or the responsibility of the CNCF or of the Cozystack maintainers acting as such. Cozystack is a trademark of the Linux Foundation, used here only to describe what these catalogs are for.

## Sections

The repository follows the component split a Linux distribution uses. **What decides the section is what this repository stores, not the licence of the software an application runs.**

| Section | What is in it | What it means for you |
| --- | --- | --- |
| [`free/`](free/) | Apache-2.0 catalogs whose applications are open source throughout — model serving (vLLM), gateways (LiteLLM), notebooks (JupyterHub), pipelines (Langflow), image generation (ComfyUI) | install and run it, no strings |
| [`contrib/`](contrib/) | Apache-2.0 catalogs whose applications are licensed by their vendors — workflow automation (n8n), chat UI (Open WebUI) | you may need your own entitlement from that vendor |

There is deliberately no `non-free` section. Debian has one because it redistributes non-free binaries; this repository never stores or redistributes vendor software at all, so the section could only ever be empty. If that principle is ever revisited, it will be a decision made in the open, not a directory quietly filling up.

## How `contrib/` works

The code in `contrib/` is Apache-2.0 and written for the purpose: charts, manifests, glue. The software it deploys is not stored here. When you install one of these applications your own cluster pulls the vendor's images and charts from the vendor's own registries, at install time, on the vendor's terms.

That distinction is the design, not a technicality — and it has a consequence you should read before installing anything. Several of these products restrict offering them to third parties as a hosted or managed service, which is precisely what a Cozystack operator does. n8n requires an Embed or Enterprise entitlement for exactly that; Open WebUI's licence keeps its branding in place for deployments above 50 users. Every application in `contrib/` states the licence of what it pulls, and any entitlement you must hold, in its own README.

## Why this is not in the Cozystack repository

A CNCF project's dependencies must clear the foundation's licensing policy, and vendor-licensed software does not, whether it is vendored or fetched at deploy time. Contributions have been turned away on those grounds alone — not for want of someone to maintain them. This repository is where that work can live instead.

## Using a catalog

Each catalog registers with a Cozystack installation as an external application source; its applications then appear alongside the built-in ones. Nothing changes in Cozystack itself, and removing the catalog removes the applications.

Where the platform already satisfies a dependency with a free default, a catalog here may add an alternative rather than replace it. The operator chooses; the default stays free.

## Contributing

Applications are maintained by the people who contribute them. If you run one of these in production and are willing to keep it working, that is who this is for.

The rules for a contribution:

- the code you write is Apache-2.0;
- vendor software is fetched by the user's cluster from the vendor, never committed here;
- the README states the licence of every non-open-source component it pulls, and any entitlement the user must hold to use it the way Cozystack operators do.

## Licence

Apache-2.0. See [LICENSE](LICENSE).
