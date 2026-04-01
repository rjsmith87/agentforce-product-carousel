# Agentforce Product Carousel

**Interactive product carousels rendered inside Salesforce Agentforce chat messages — not beside them, not linked from them, but *inside* the message bubble itself.**

This project solves a problem most Salesforce developers don't know exists: there is no supported way to render custom UI components inside an Agentforce conversation. This repo implements a working solution using a three-piece chain of Lightning Types, Apex, and LWC that injects a navigable image carousel directly into the agent's chat stream.

No external libraries. No open source dependencies. Zero runtime packages. Built entirely on native Salesforce platform primitives.

---

## Why This Is Hard

Agentforce agents respond in plain text. When a customer asks "show me your safety boots," the agent can *describe* products — but it can't *show* them. Every standard approach to rendering custom UI in Salesforce fails inside the Agentforce chat window:

**You can't place an LWC in a message bubble.** Normal Lightning Web Components are placed on record pages, app pages, or home pages via App Builder. The Agentforce chat window is a messaging surface — there is no flexipage slot, no `<lightning-record-view>`, no drag-and-drop target.

**`@api recordId` doesn't exist in a chat message.** Standard LWC patterns depend on being placed on a record page where the platform injects context. Inside a chat message, there is no record context. The component has no idea what it's supposed to render.

**Aura events and Lightning Message Service can't reach into the message stream.** Those communication patterns work between components on the same page. A chat message isn't a page — it's a rendered frame inside the messaging framework's own DOM.

**The messaging framework renders text and structured content types, not arbitrary components.** When an agent responds, the messaging UI receives the response payload and renders it as text (or a simple structured card). There is no documented mechanism to inject a full interactive LWC into that render path.

Most developers stop here and build a link-out pattern: the agent sends a URL, the user clicks it, and a separate page renders the product catalog. That works, but it breaks the conversational flow and loses the context of the chat.

---

## The Breakthrough

The solution exploits a capability that Lightning Types weren't primarily designed for: **UI rendering overrides on messaging surfaces.**

Lightning Types were built for structured data exchange between Flows, Apex, and AI agents. But Salesforce also built a `renderer.json` system that allows a Lightning Type to declare how it should be *displayed* on specific surfaces. By registering a custom LWC as the renderer for a Lightning Type, you can make the messaging framework render your component instead of plain text — directly inside the chat bubble.

The implementation is a three-piece chain:

### Piece 1: `AsaCarouselData.cls` (The Data Container)

```java
@JsonAccess(serializable='always' deserializable='always')
global class AsaCarouselData {
    @AuraEnabled
    global String productCarouselJSON;
}
```

A global Apex class that holds product data as a serialized JSON string. Marked with `@JsonAccess` so the platform can serialize/deserialize it across boundaries. This is the typed envelope that carries carousel data through the system.

### Piece 2: `schema.json` (The Type Registration)

```json
{
  "title": "ASA Product Carousel Response",
  "lightning:type": "@apexClassType/c__AsaCarouselData"
}
```

A Lightning Type definition that tells the platform: "when you encounter an `AsaCarouselData` object, treat it as a structured type called 'ASA Product Carousel Response.'" This registers the Apex class as a first-class type that the messaging framework can recognize.

### Piece 3: `renderer.json` (The UI Override)

```json
{
  "renderer": {
    "componentOverrides": {
      "$": {
        "definition": "c/asaCarousel"
      }
    }
  }
}
```

This is the key file. It tells the messaging framework: "instead of rendering this data type as plain text, render it using the `c/asaCarousel` LWC component." There are two copies — one for `lightningDesktopGenAi` (the Agentforce panel in the desktop app) and one for `lightningSnapinAgentforce` (the embedded web chat widget). Both point to the same carousel component.

The result: when the agent returns an `AsaCarouselData` object in a conversation, the messaging framework automatically looks up the renderer override and **injects the full interactive carousel — product images, navigation arrows, dot indicators — directly into the chat message bubble.**

---

## Architecture

```
  Customer: "Show me your boots"
        |
        v
  +-------------------------------------------------------------+
  |  AGENTFORCE AGENT                                           |
  |                                                             |
  |  GenAI Planner routes to product catalog topic              |
  |  Agent calls invocable Apex action                          |
  |                                                             |
  |  +-------------------------------------------------------+  |
  |  |  PPECarouselAction.cls (@InvocableMethod)              |  |
  |  |                                                        |  |
  |  |  SELECT Id, Name, ImageURL__c, Category__c             |  |
  |  |  FROM PPEProduct__c                                    |  |
  |  |  WHERE InStock__c = true                               |  |
  |  |  AND Name LIKE '%boot%'                                |  |
  |  |                                                        |  |
  |  |  Returns: [mimeType, recordUrl, imageUrl, name] x N    |  |
  |  +----------------------------+---------------------------+  |
  |                               |                              |
  |  +----------------------------v---------------------------+  |
  |  |  Format_Output Flow                                    |  |
  |  |                                                        |  |
  |  |  Wraps product data into AsaCarouselData object:       |  |
  |  |  {                                                     |  |
  |  |    "products": [                                       |  |
  |  |      {"title": "...", "imageUrl": "...",               |  |
  |  |       "description": "...", "stage": "..."}            |  |
  |  |    ]                                                   |  |
  |  |  }                                                     |  |
  |  |                                                        |  |
  |  |  Output variable type: AsaCarouselData (Apex class)    |  |
  |  +----------------------------+---------------------------+  |
  |                               |                              |
  +-------------------------------+------------------------------+
                                  |
              THE THREE-PIECE CHAIN
                                  |
  +-------------------------------v------------------------------+
  |  1. AsaCarouselData.cls                                      |
  |     Global Apex class with @JsonAccess                       |
  |     Holds productCarouselJSON as serialized string           |
  +-------------------------------+------------------------------+
                                  |
  +-------------------------------v------------------------------+
  |  2. schema.json (Lightning Type)                             |
  |     "lightning:type": "@apexClassType/c__AsaCarouselData"    |
  |     Registers the Apex class as a platform-recognized type   |
  +-------------------------------+------------------------------+
                                  |
  +-------------------------------v------------------------------+
  |  3. renderer.json (Component Override)                       |
  |     "componentOverrides": {"$": {"definition":"c/asaCarousel"|
  |                                                              |
  |     lightningDesktopGenAi/renderer.json  --> Desktop panel   |
  |     lightningSnapinAgentforce/renderer.json --> Web chat      |
  +-------------------------------+------------------------------+
                                  |
  +-------------------------------v------------------------------+
  |  CHAT MESSAGE BUBBLE                                         |
  |                                                              |
  |  +--------+ +--------+ +--------+                           |
  |  | Boot 1 | | Boot 2 | | Boot 3 |                           |
  |  | [IMG]  | | [IMG]  | | [IMG]  |                           |
  |  | S3 Hi  | | Plstc  | | Light  |                           |
  |  +--------+ +--------+ +--------+                           |
  |        <--   * * *   -->                                     |
  |  Arrow navigation + dot indicators                          |
  |  Full interactive LWC inside the message                    |
  +-------------------------------------------------------------+
```

---

## Tech Stack

| Layer | Technology | Purpose |
|:------|:-----------|:--------|
| **AI Agent** | Salesforce Agentforce | Conversational product assistant |
| **Backend Logic** | Apex (Invocable Actions) | Product queries, order creation, status lookup |
| **Rich UI** | Lightning Web Components | Carousel renderer inside agent messages |
| **Type System** | Lightning Types + `renderer.json` | Bridge between Apex data and LWC rendering in chat |
| **Data Model** | Custom Objects (Product, Article, Case) | Product catalog and order tracking |
| **Agent Config** | GenAI Functions + Planner Bundles | Agent topic routing and action binding |
| **Messaging** | Embedded Messaging + Desktop GenAI | Dual-surface delivery (web chat + desktop panel) |
| **Permissions** | Permission Sets | Product catalog read access control |
| **API** | Apex REST (`/agentforce/*`) | External integration endpoint |

---

## Multi-Surface Support

The carousel works on **both** Agentforce surfaces because the Lightning Type has two separate renderer registrations:

```
ASA_ProductCarouselCardsStage/
  main/default/lightningTypes/asaCarousel/
    schema.json                              # Type definition (shared)
    lightningDesktopGenAi/renderer.json      # Desktop Agentforce panel
    lightningSnapinAgentforce/renderer.json  # Embedded web chat widget
```

Both renderers point to the same `c/asaCarousel` LWC. The component itself is surface-agnostic — it receives the `AsaCarouselData` object via `@api value`, parses the JSON, and renders the carousel. The messaging framework handles the injection.

---

## Key Components

### Apex Classes

| Class | Purpose |
|:------|:--------|
| `AsaCarouselData.cls` | Lightning Type backing class — the data envelope |
| `PPECarouselAction.cls` | Invocable action: queries product catalog, returns carousel data |
| `CreatePPEOrder.cls` | Invocable action: creates order Cases with size validation |
| `CreatePPEArticlesFromJSON.cls` | Parses JSON payloads, normalizes names/sizes, creates records |
| `GetPPEOrderStatus.cls` | Invocable action: order status lookup by case number or name |
| `AgentforceREST.cls` | REST endpoint with product keyword detection |

### Lightning Web Components

| Component | Purpose |
|:----------|:--------|
| `asaCarousel` | Product carousel with image cards, arrow nav, dot indicators |
| `ppeOrderConfirmation` | Order confirmation grid with item details |

---

## Repository Structure

```
agentforce-product-carousel/
├── force-app/main/default/
│   ├── classes/                    # Apex invocable actions + REST endpoint
│   ├── lwc/
│   │   ├── asaCarousel/            # The carousel component (JS, HTML, CSS)
│   │   └── ppeOrderConfirmation/   # Order confirmation component
│   ├── bots/                       # Agentforce agent configuration
│   ├── flows/                      # Format_Output, order flows
│   ├── genAiFunctions/             # Agent action definitions
│   ├── genAiPlannerBundles/        # Agent topic routing
│   ├── objects/                    # Custom object metadata
│   └── permissionsets/             # Catalog access permissions
├── ASA_ProductCarouselCardsStage/   # Lightning Type + renderer package
│   └── main/default/
│       ├── lightningTypes/asaCarousel/
│       │   ├── schema.json         # Type registration
│       │   ├── lightningDesktopGenAi/renderer.json
│       │   └── lightningSnapinAgentforce/renderer.json
│       ├── classes/AsaCarouselData.cls
│       ├── lwc/asaCarousel/        # Staging copy of carousel
│       └── flows/Format_Output.flow-meta.xml
├── data/                           # Sample product seed data
├── config/                         # Scratch org definition
└── sfdx-project.json               # SFDX project config
```

---

## Setup

### Prerequisites
- Salesforce org with Agentforce enabled
- Salesforce CLI (sf/sfdx)

### Deploy
```bash
sf project deploy start --source-dir force-app
sf project deploy start --source-dir ASA_ProductCarouselCardsStage
```

### Seed Sample Data
```bash
sf data import tree --files data/Article__c.json
```

### Configure Agent
1. Deploy both metadata directories to your org
2. Update the bot user email to match your org ID
3. Activate the agent in Agentforce Studio
4. Enable Embedded Messaging or Enhanced Chat
5. Test: ask the agent "show me your products"

---

## License

MIT
