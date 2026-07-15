# DAX Measures Reference

Full reference for the custom DAX measures used in the Power BI report. See the main [README](../README.md) for context on how these fit into the dashboard.

---

## Core KPIs

### Total Revenue

```dax
Total Revenue = SUM(order_items[price_usd])
```

Sum of item-level revenue across all order items.

---

### Total Profit

```dax
Total Profit = SUM(order_items[price_usd]) - SUM(order_items[cogs_usd])
```

Item-level revenue minus cost of goods sold.

---

### Average Order Value

```dax
Average Order Value = DIVIDE(SUM(order_items[price_usd]), COUNT(orders[order_id]), 0)
```

Average revenue per completed order. Uses `DIVIDE()` for safe handling of the zero-denominator case.

---

## Conversion & Funnel

### Conversion Rate %

```dax
Conversion Rate % = DIVIDE(DISTINCTCOUNT(orders[order_id]), DISTINCTCOUNT(website_sessions[website_session_id]), 0)
```

Share of website sessions that resulted in a completed order.

---

### Cart Abandonment Rate %

```dax
Cart Abandonment Rate % = 

VAR Total_Order = CALCULATE(DISTINCTCOUNT(website_pageviews[website_session_id]), website_pageviews[pageview_url] = "/thank-you-for-your-order")
VAR Total_Carts_Created = CALCULATE(DISTINCTCOUNT(website_pageviews[website_session_id]), website_pageviews[pageview_url] = "/cart")

RETURN
(1 - Total_Order / Total_Carts_Created)
```

Percentage of sessions that added an item to the cart but left without completing the purchase. Uses `VAR`/`RETURN` for readability rather than nesting `CALCULATE` calls inline.

---

### Funnel Step

```dax
Funnel Step = 

SWITCH(
    TRUE,
    website_pageviews[pageview_url] IN {"/home", "/lander-1", "/lander-2", "/lander-3", "/lander-4", "/lander-5"}, "Home",
    website_pageviews[pageview_url] = "/products", "Products",
    website_pageviews[pageview_url] IN {"/the-birthday-sugar-panda", "/the-forever-love-bear", "/the-hudson-river-mini-bear", "/the-original-mr-fuzzy"}, "Product Details",
    website_pageviews[pageview_url] = "/cart", "Cart",
    website_pageviews[pageview_url] = "/shipping", "Shipping",
    website_pageviews[pageview_url] IN {"/billing", "/billing-2"}, "Billing",
    website_pageviews[pageview_url] = "/thank-you-for-your-order", "Order Complete",
    "Unknown"
)
```

Classifies each pageview into its corresponding funnel stage, used to power the funnel visual.

---

### Revenue per Session

```dax
Revenue per Session = DIVIDE(SUM(orders[price_usd]), DISTINCTCOUNT(website_sessions[website_session_id]), 0)
```

Revenue generated per website session — captures the combined effect of conversion rate and order value in a single number.

---

## Product Quality

### Refund Rate %

```dax
Refund Rate % = 

VAR Total_Order_Refunded = DISTINCTCOUNT(order_item_refunds[order_item_refund_id])
VAR Total_Order = DISTINCTCOUNT(order_items[order_item_id])

RETURN
DIVIDE(Total_Order_Refunded, Total_Order, 0) 
```

Share of order items that were refunded.

