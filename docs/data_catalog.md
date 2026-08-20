# Data Catalog — Gold Layer

The Gold layer is the business-ready star schema, exposed as SQL views over the Silver layer. It contains two dimension views and one fact view. This catalog documents every column for analysts and stakeholders who query the warehouse without reading the underlying SQL.

---

## gold.dim_customers

**Grain:** one row per customer.
**Source:** `silver.crm_cust_info`, enriched with `silver.erp_cust_az12` (demographics) and `silver.erp_loc_a101` (location).

| Column | Type | Description |
|---|---|---|
| `customer_key` | bigint | Surrogate key. Warehouse-generated sequential id; primary key of the dimension and the join target for `fact_sales`. |
| `customer_id` | integer | Original customer id from the CRM source system. |
| `customer_number` | varchar | Alphanumeric customer code from the CRM system; used to join to the ERP sources. |
| `first_name` | varchar | Customer first name (whitespace-trimmed in Silver). |
| `last_name` | varchar | Customer last name (whitespace-trimmed in Silver). |
| `country` | varchar | Country of residence, sourced from ERP location data and expanded from codes (e.g. `DE` → `Germany`). `n/a` where missing. |
| `marital_status` | varchar | Decoded marital status: `Single`, `Married`, or `n/a`. |
| `gender` | varchar | `Male`, `Female`, or `n/a`. CRM is the source of truth; ERP is used as a fallback only where CRM is unknown. |
| `birthdate` | date | Date of birth from ERP demographics. Future-dated values were nulled in Silver. |
| `create_date` | date | Date the customer record was created in the CRM source system. |

---

## gold.dim_products

**Grain:** one row per **current** product. Historical product versions are excluded (`prd_end_dt IS NULL` in Silver).
**Source:** `silver.crm_prd_info`, joined to `silver.erp_px_cat_g1v2` (category lookup) on the derived `category_id`.

| Column | Type | Description |
|---|---|---|
| `product_key` | bigint | Surrogate key. Warehouse-generated sequential id; primary key of the dimension and the join target for `fact_sales`. |
| `product_id` | integer | Original product id from the CRM source system. |
| `product_number` | varchar | Alphanumeric product code (derived from the raw product key in Silver); used to join to sales details. |
| `product_name` | varchar | Product name. |
| `category_id` | varchar | Category id derived from the first segment of the raw product key; joins to the ERP category table. |
| `category` | varchar | High-level product category (from ERP category lookup). |
| `subcategory` | varchar | Product subcategory (from ERP category lookup). |
| `maintenance` | varchar | Maintenance flag/attribute from the ERP category lookup. |
| `cost` | integer | Product cost. Missing values set to `0` in Silver. |
| `product_line` | varchar | Decoded product line: `Mountain`, `Road`, `Other Sales`, `Touring`, or `n/a`. |
| `start_date` | date | Date this product version became effective. |

---

## gold.fact_sales

**Grain:** one row per sales order line.
**Source:** `silver.crm_sales_details`, with business keys replaced by surrogate keys via joins to `gold.dim_products` and `gold.dim_customers`.

| Column | Type | Description |
|---|---|---|
| `order_number` | varchar | Sales order number. Not unique across rows — one order may span multiple product lines. |
| `product_key` | bigint | Foreign key to `gold.dim_products`. |
| `customer_key` | bigint | Foreign key to `gold.dim_customers`. |
| `order_date` | date | Date the order was placed. Invalid source values (zeros / wrong length) were nulled in Silver. |
| `shipping_date` | date | Date the order shipped. |
| `due_date` | date | Date the order was due. |
| `sales_amount` | integer | Line sales amount. Recalculated as `quantity × price` in Silver where the source value was missing or inconsistent. |
| `quantity` | integer | Units sold on the line. |
| `price` | integer | Unit price. Re-derived from `sales / quantity` in Silver where the source value was invalid. |

---

## Measures (for BI)

The following are the natural measures for a semantic model built on `fact_sales`:

- **Total Sales** = SUM(`sales_amount`)
- **Total Quantity** = SUM(`quantity`)
- **Total Orders** = distinct count of `order_number`
- **Average Order Value** = Total Sales ÷ Total Orders

Dimensions (`dim_customers`, `dim_products`, and a date dimension if added) provide the slice-by attributes: country, category, product line, marital status, gender, and time.
