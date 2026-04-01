# Agentforce Product Carousel

**Custom Apex + LWC implementation that renders interactive product carousels inside Salesforce Agentforce conversations — enabling AI agents to visually present, filter, and sell products directly within a chat interface.**

---

## The Problem

Salesforce Agentforce agents communicate in plain text by default. When a customer asks "show me your safety boots," the agent can describe products — but it can't *show* them. There's no native way to render rich, interactive product cards inside an Agentforce conversation. This forces customers into a text-only ordering flow where they can't see what they're buying.

## The Solution

This project implements a **custom Lightning Type + LWC rendering pattern** that injects visual product carousels directly into the Agentforce message stream. When the agent detects a product-related query, it:

1. Queries the product catalog via an invocable Apex action
2. Serializes product data (images, names, descriptions) into a custom Lightning Type (`AsaCarouselData`)
3. The Lightning Type triggers a custom LWC renderer (`asaCarousel`) inside the messaging UI
4. The customer sees navigable product cards with images, descriptions, and stage/time badges — inline with the conversation

This is a non-trivial integration because Agentforce's messaging layer doesn't natively support custom UI components. The solution bridges Apex invocable actions, Lightning Types, and LWC renderers through a pattern that works across both Embedded Messaging and Desktop GenAI surfaces.

---

## Tech Stack

| Layer | Technology | Purpose |
|:------|:-----------|:--------|
| **AI Agent** | Salesforce Agentforce | Conversational product assistant |
| **Backend Logic** | Apex (Invocable Actions) | Product queries, order creation, status lookup |
| **Rich UI** | Lightning Web Components | Carousel renderer inside agent messages |
| **Type System** | Lightning Types | Bridge between Apex data and LWC rendering |
| **Data Model** | Custom Objects (Product, Article, Case) | Product catalog and order tracking |
| **Agent Config** | GenAI Functions + Planner Bundles | Agent topic routing and action binding |
| **Messaging** | Embedded Messaging / Enhanced Chat | Multi-channel delivery surface |
| **Permissions** | Permission Sets | Product catalog read access control |
| **API** | Apex REST (`/agentforce/*`) | External integration endpoint |

---

## Architecture

```
  Customer: "Show me your boots"
        |
        v
  +-------------------------------------------------------------+
  |  AGENTFORCE AGENT                                           |
  |                                                             |
  |  1. GenAI Planner routes to "Product Catalog" topic         |
  |  2. Agent calls invocable action (PPECarouselAction)        |
  |                                                             |
  |  +-------------------------------------------------------+  |
  |  |  Apex: PPECarouselAction.cls                           |  |
  |  |  - Queries PPEProduct__c (filtered by category/        |  |
  |  |    search term, with plural normalization)             |  |
  |  |  - Returns: MIME type, record URL, image URL, name    |  |
  |  +-------------------------+-----------------------------+  |
  |                            |                                |
  |  +-------------------------v-----------------------------+  |
  |  |  Flow: Format_Output                                  |  |
  |  |  - Wraps product data into AsaCarouselData            |  |
  |  |  - Serializes: {products: [{title, imageUrl,          |  |
  |  |    description, time, stage}]}                        |  |
  |  +-------------------------+-----------------------------+  |
  +----------------------------+--------------------------------+
                               |
  +----------------------------v--------------------------------+
  |  LIGHTNING TYPE: AsaCarouselData                             |
  |  - Global Apex class with @JsonAccess                       |
  |  - schema.json maps to c/asaCarousel renderer               |
  |  - Works on Desktop GenAI + Snapin Agentforce surfaces      |
  +----------------------------+--------------------------------+
                               |
  +----------------------------v--------------------------------+
  |  LWC: asaCarousel                                           |
  |  +--------+ +--------+ +--------+                          |
  |  | Boot   | | Gloves | | Helmet |  <-- * * * -->            |
  |  | [img]  | | [img]  | | [img]  |                          |
  |  | $49.99 | | $24.99 | | $34.99 |                          |
  |  +--------+ +--------+ +--------+                          |
  |  Arrow navigation + dot indicators                         |
  +-------------------------------------------------------------+

  ORDER FLOW (when customer selects a product):
  +-------------------------------------------------------------+
  |  AgentforceREST.cls (REST /agentforce/*)                    |
  |  - Detects product keywords in user message                 |
  |  - Invokes agent with product context                       |
  |  - Agent calls CreatePPEOrder -> creates Case               |
  |  - GetPPEOrderStatus -> retrieves order tracking            |
  +-------------------------------------------------------------+
```

---

## Key Components

### Apex Classes

| Class | Purpose |
|:------|:--------|
| `AsaCarouselData.cls` | Global Lightning Type backing class — serializes product JSON for LWC |
| `PPECarouselAction.cls` | Invocable action that queries product catalog with search/category filtering |
| `CreatePPEOrder.cls` | Invocable action that creates order Cases with size validation |
| `CreatePPEArticlesFromJSON.cls` | Parses JSON payloads, normalizes article names/sizes, creates records |
| `GetPPEOrderStatus.cls` | Invocable action for order status lookup by case number or name |
| `AgentforceREST.cls` | REST endpoint for external integrations with product detection |
| `PPEOrderConfirmationController.cls` | VF controller for order confirmation page |

### Lightning Web Components

| Component | Purpose |
|:----------|:--------|
| `asaCarousel` | Card-based product carousel with image, title, description, navigation |
| `ppeOrderConfirmation` | Order confirmation display with item grid |

### Lightning Types

| File | Purpose |
|:-----|:--------|
| `schema.json` | Defines `AsaCarouselData` as the backing Apex type |
| `renderer.json` | Maps to `c/asaCarousel` for both Desktop GenAI and Snapin Agentforce |

---

## Why This Is Novel

Agentforce doesn't ship with a way to render custom UI inside agent messages. The standard approach is text-only responses. This project solves that by chaining three Salesforce features that weren't designed to work together:

1. **Lightning Types** — originally built for structured data exchange, repurposed here as a bridge between Apex serialized data and LWC rendering
2. **LWC Custom Renderers** — the `renderer.json` file overrides how the Lightning Type is displayed, injecting a full carousel component into the message bubble
3. **Invocable Actions as Data Sources** — the agent's planner calls Apex invocable methods that return `AsaCarouselData`, which the messaging framework automatically renders via the registered LWC

This pattern is reusable for any rich content in Agentforce: image galleries, data tables, charts, or interactive forms.

---

## Repository Structure

```
agentforce-product-carousel/
├── force-app/main/default/
│   ├── classes/                    # Apex invocable actions + REST endpoint
│   ├── lwc/
│   │   ├── asaCarousel/            # Product carousel component
│   │   └── ppeOrderConfirmation/   # Order confirmation component
│   ├── bots/                       # Agentforce agent configuration
│   ├── flows/                      # Order creation and status flows
│   ├── genAiFunctions/             # Agent action definitions
│   ├── genAiPlannerBundles/        # Agent topic routing
│   ├── objects/                    # Custom object metadata
│   ├── permissionsets/             # Catalog access permissions
│   ├── pages/                      # Visualforce test page
│   └── aura/                       # Aura test app wrapper
├── ASA_ProductCarouselCardsStage/   # Staging package (carousel + flow)
├── asa-package/                    # Deployable unmanaged package
├── data/                           # Sample product seed data
├── config/                         # Scratch org definition
├── sfdx-project.json               # SFDX project config
└── package.json                    # Node dependencies (ESLint, Prettier, Jest)
```

---

## Setup

### Prerequisites
- Salesforce org with Agentforce enabled
- Salesforce CLI (sf/sfdx)
- Node.js (for linting/testing)

### Deploy
```bash
sf project deploy start --source-dir force-app
```

### Seed Sample Data
```bash
sf data import tree --files data/Article__c.json
```

### Configure Agent
1. Deploy the metadata to your org
2. Update the bot user email in the agent configuration to match your org
3. Activate the agent in Agentforce Studio
4. Enable Embedded Messaging or Enhanced Chat

---

## License

MIT
