-- MySQL 8 importable schema (12 tables) for NL2SQL demos
-- Domain: E-commerce ordering + fulfillment
--
-- Notes:
--  - Uses InnoDB + utf8mb4
--  - Clear PK/FK relationships
--  - Includes unique keys, composite keys, and indexes
--  - Safe to import into an empty MySQL 8 instance

SET NAMES utf8mb4;
SET time_zone = '+00:00';

-- Create database (optional). Comment out if you want to use an existing DB.
CREATE DATABASE IF NOT EXISTS nl2sql_demo
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;
USE nl2sql_demo;

-- Make reload/import smoother.
SET FOREIGN_KEY_CHECKS = 0;

-- Drop in dependency order (children first)
DROP TABLE IF EXISTS shipment_items;
DROP TABLE IF EXISTS shipments;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS cart_items;
DROP TABLE IF EXISTS carts;
DROP TABLE IF EXISTS product_images;
DROP TABLE IF EXISTS product_category_map;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS vendors;
DROP TABLE IF EXISTS customer_addresses;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS countries;

-- ---------- Reference tables ----------
CREATE TABLE countries (
  country_code CHAR(2) NOT NULL COMMENT 'ISO-3166-1 alpha-2',
  name         VARCHAR(100) NOT NULL,
  PRIMARY KEY (country_code),
  UNIQUE KEY ux_countries_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ---------- Customers ----------
CREATE TABLE customers (
  customer_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  email       VARCHAR(255) NOT NULL,
  full_name   VARCHAR(150) NOT NULL,
  phone       VARCHAR(30) NULL,
  created_at  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (customer_id),
  UNIQUE KEY ux_customers_email (email),
  KEY ix_customers_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE customer_addresses (
  address_id    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  customer_id   BIGINT UNSIGNED NOT NULL,
  label         VARCHAR(50) NULL COMMENT 'e.g. Home, Work',
  line1         VARCHAR(200) NOT NULL,
  line2         VARCHAR(200) NULL,
  city          VARCHAR(100) NOT NULL,
  state_region  VARCHAR(100) NULL,
  postal_code   VARCHAR(20) NULL,
  country_code  CHAR(2) NOT NULL,
  is_default    BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at    DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (address_id),
  KEY ix_customer_addresses_customer_default (customer_id, is_default),
  KEY ix_customer_addresses_country (country_code),
  CONSTRAINT fk_customer_addresses_customer
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
    ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT fk_customer_addresses_country
    FOREIGN KEY (country_code) REFERENCES countries(country_code)
    ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ---------- Vendors + Catalog ----------
CREATE TABLE vendors (
  vendor_id    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name         VARCHAR(150) NOT NULL,
  slug         VARCHAR(120) NOT NULL COMMENT 'Unique vendor handle used in URLs',
  support_email VARCHAR(255) NULL,
  created_at   DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at   DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (vendor_id),
  UNIQUE KEY ux_vendors_slug (slug),
  UNIQUE KEY ux_vendors_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE products (
  product_id   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  vendor_id    BIGINT UNSIGNED NOT NULL,
  sku          VARCHAR(64) NOT NULL,
  name         VARCHAR(200) NOT NULL,
  description  TEXT NULL,
  price        DECIMAL(12,2) NOT NULL,
  currency     CHAR(3) NOT NULL DEFAULT 'USD',
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at   DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at   DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (product_id),
  UNIQUE KEY ux_products_sku (sku),
  KEY ix_products_vendor_active (vendor_id, is_active),
  KEY ix_products_vendor_created (vendor_id, created_at),
  CONSTRAINT fk_products_vendor
    FOREIGN KEY (vendor_id) REFERENCES vendors(vendor_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_products_price_nonnegative CHECK (price >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE categories (
  category_id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name               VARCHAR(120) NOT NULL,
  slug               VARCHAR(140) NOT NULL,
  parent_category_id BIGINT UNSIGNED NULL,
  created_at         DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at         DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (category_id),
  UNIQUE KEY ux_categories_slug (slug),
  KEY ix_categories_parent (parent_category_id),
  CONSTRAINT fk_categories_parent
    FOREIGN KEY (parent_category_id) REFERENCES categories(category_id)
    ON DELETE SET NULL ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Many-to-many: products <-> categories
CREATE TABLE product_category_map (
  product_id  BIGINT UNSIGNED NOT NULL,
  category_id BIGINT UNSIGNED NOT NULL,
  created_at  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (product_id, category_id) COMMENT 'Composite PK prevents duplicates',
  KEY ix_pcm_category_product (category_id, product_id),
  CONSTRAINT fk_pcm_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT fk_pcm_category
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
    ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE product_images (
  image_id   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  product_id BIGINT UNSIGNED NOT NULL,
  url        VARCHAR(500) NOT NULL,
  alt_text   VARCHAR(200) NULL,
  sort_order INT NOT NULL DEFAULT 0,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (image_id),
  UNIQUE KEY ux_product_images_product_url (product_id, url),
  KEY ix_product_images_product_sort (product_id, sort_order),
  CONSTRAINT fk_product_images_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Product images; unique URL per product; ordered by sort_order';

-- ---------- Cart ----------
CREATE TABLE carts (
  cart_id     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  customer_id BIGINT UNSIGNED NOT NULL,
  status      ENUM('ACTIVE','ORDERED','ABANDONED') NOT NULL DEFAULT 'ACTIVE',
  created_at  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (cart_id),
  KEY ix_carts_customer_status (customer_id, status),
  CONSTRAINT fk_carts_customer
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
    ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE cart_items (
  cart_id    BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  quantity   INT NOT NULL,
  unit_price DECIMAL(12,2) NOT NULL COMMENT 'Snapshot price at time of cart update',
  added_at   DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (cart_id, product_id),
  KEY ix_cart_items_product (product_id),
  CONSTRAINT fk_cart_items_cart
    FOREIGN KEY (cart_id) REFERENCES carts(cart_id)
    ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT fk_cart_items_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_cart_items_qty_positive CHECK (quantity > 0),
  CONSTRAINT ck_cart_items_unit_price_nonnegative CHECK (unit_price >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Cart line items; composite PK (cart_id, product_id) prevents duplicate items';

-- ---------- Orders ----------
CREATE TABLE orders (
  order_id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  customer_id           BIGINT UNSIGNED NOT NULL,
  shipping_address_id   BIGINT UNSIGNED NULL,
  billing_address_id    BIGINT UNSIGNED NULL,
  order_number          VARCHAR(30) NOT NULL COMMENT 'Business identifier',
  status                ENUM('PENDING','PAID','SHIPPED','DELIVERED','CANCELLED','REFUNDED') NOT NULL DEFAULT 'PENDING',
  currency              CHAR(3) NOT NULL DEFAULT 'USD',
  subtotal              DECIMAL(12,2) NOT NULL DEFAULT 0,
  shipping_fee          DECIMAL(12,2) NOT NULL DEFAULT 0,
  tax_amount            DECIMAL(12,2) NOT NULL DEFAULT 0,
  total_amount          DECIMAL(12,2) NOT NULL DEFAULT 0,
  created_at            DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at            DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (order_id),
  UNIQUE KEY ux_orders_order_number (order_number),
  KEY ix_orders_customer_created (customer_id, created_at),
  KEY ix_orders_status_created (status, created_at),
  CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_orders_shipping_address
    FOREIGN KEY (shipping_address_id) REFERENCES customer_addresses(address_id)
    ON DELETE SET NULL ON UPDATE RESTRICT,
  CONSTRAINT fk_orders_billing_address
    FOREIGN KEY (billing_address_id) REFERENCES customer_addresses(address_id)
    ON DELETE SET NULL ON UPDATE RESTRICT,
  CONSTRAINT ck_orders_amounts_nonnegative CHECK (
    subtotal >= 0 AND shipping_fee >= 0 AND tax_amount >= 0 AND total_amount >= 0
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE order_items (
  order_item_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id      BIGINT UNSIGNED NOT NULL,
  line_number   INT NOT NULL,
  product_id    BIGINT UNSIGNED NULL,
  sku           VARCHAR(64) NOT NULL,
  product_name  VARCHAR(200) NOT NULL,
  quantity      INT NOT NULL,
  unit_price    DECIMAL(12,2) NOT NULL,
  created_at    DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (order_item_id),
  UNIQUE KEY ux_order_items_order_line (order_id, line_number),
  KEY ix_order_items_order (order_id),
  KEY ix_order_items_product (product_id),
  CONSTRAINT fk_order_items_order
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
    ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT fk_order_items_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON DELETE SET NULL ON UPDATE RESTRICT,
  CONSTRAINT ck_order_items_qty_positive CHECK (quantity > 0),
  CONSTRAINT ck_order_items_unit_price_nonnegative CHECK (unit_price >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Order line items; unique (order_id, line_number) makes line ordering stable';

-- ---------- Payments ----------
CREATE TABLE payments (
  payment_id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id                BIGINT UNSIGNED NOT NULL,
  provider                VARCHAR(40) NOT NULL COMMENT 'e.g. stripe, paypal',
  provider_transaction_id VARCHAR(100) NOT NULL,
  status                  ENUM('INITIATED','AUTHORIZED','CAPTURED','FAILED','REFUNDED') NOT NULL,
  amount                  DECIMAL(12,2) NOT NULL,
  currency                CHAR(3) NOT NULL DEFAULT 'USD',
  created_at              DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (payment_id),
  UNIQUE KEY ux_payments_provider_tx (provider, provider_transaction_id),
  KEY ix_payments_order_created (order_id, created_at),
  KEY ix_payments_status_created (status, created_at),
  CONSTRAINT fk_payments_order
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
    ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT ck_payments_amount_nonnegative CHECK (amount >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ---------- Fulfillment ----------
CREATE TABLE shipments (
  shipment_id      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id         BIGINT UNSIGNED NOT NULL,
  carrier          VARCHAR(60) NULL,
  tracking_number  VARCHAR(80) NULL,
  status           ENUM('PENDING','PACKED','SHIPPED','DELIVERED','RETURNED','CANCELLED') NOT NULL DEFAULT 'PENDING',
  shipped_at       DATETIME(3) NULL,
  delivered_at     DATETIME(3) NULL,
  created_at       DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at       DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (shipment_id),
  UNIQUE KEY ux_shipments_tracking (carrier, tracking_number),
  KEY ix_shipments_order_status (order_id, status),
  KEY ix_shipments_status_shipped (status, shipped_at),
  CONSTRAINT fk_shipments_order
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
    ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE shipment_items (
  shipment_item_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  shipment_id      BIGINT UNSIGNED NOT NULL,
  order_item_id    BIGINT UNSIGNED NOT NULL,
  quantity         INT NOT NULL,
  created_at       DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (shipment_item_id),
  UNIQUE KEY ux_shipment_items_shipment_order_item (shipment_id, order_item_id),
  KEY ix_shipment_items_order_item (order_item_id),
  CONSTRAINT fk_shipment_items_shipment
    FOREIGN KEY (shipment_id) REFERENCES shipments(shipment_id)
    ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT fk_shipment_items_order_item
    FOREIGN KEY (order_item_id) REFERENCES order_items(order_item_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_shipment_items_qty_positive CHECK (quantity > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

SET FOREIGN_KEY_CHECKS = 1;

-- ------------------------------
-- Sample data (all tables)
-- ------------------------------
-- Uses explicit IDs for clarity and to keep FK relationships obvious.

-- Reference
INSERT INTO countries(country_code, name) VALUES
  ('US','United States'),
  ('GB','United Kingdom'),
  ('IN','India');

-- Customers
INSERT INTO customers(customer_id, email, full_name, phone, created_at, updated_at) VALUES
  (1, 'alice@example.com', 'Alice Johnson', '+1-555-0101', '2025-01-10 10:00:00.000', '2025-01-10 10:00:00.000'),
  (2, 'bob@example.com',   'Bob Singh',      '+91-555-0202', '2025-01-11 09:30:00.000', '2025-01-11 09:30:00.000'),
  (3, 'chris@example.com', 'Chris Brown',    '+44-555-0303', '2025-01-12 14:15:00.000', '2025-01-12 14:15:00.000');

INSERT INTO customer_addresses(address_id, customer_id, label, line1, line2, city, state_region, postal_code, country_code, is_default, created_at, updated_at) VALUES
  (1, 1, 'Home',  '12 Market St',  NULL,        'San Francisco', 'CA',  '94105', 'US', TRUE,  '2025-01-10 10:05:00.000', '2025-01-10 10:05:00.000'),
  (2, 1, 'Work',  '200 Pine Ave',  'Suite 9',   'San Francisco', 'CA',  '94104', 'US', FALSE, '2025-01-10 10:06:00.000', '2025-01-10 10:06:00.000'),
  (3, 2, 'Home',  '77 MG Road',    NULL,        'Bengaluru',     'KA',  '560001','IN', TRUE,  '2025-01-11 10:00:00.000', '2025-01-11 10:00:00.000'),
  (4, 3, 'Home',  '5 King Street', NULL,        'London',       NULL,  'SW1A 1AA','GB', TRUE, '2025-01-12 15:00:00.000', '2025-01-12 15:00:00.000');

-- Vendors
INSERT INTO vendors(vendor_id, name, slug, support_email, created_at, updated_at) VALUES
  (1, 'Acme Gadgets',   'acme-gadgets',   'support@acme.example',   '2025-01-01 08:00:00.000', '2025-01-01 08:00:00.000'),
  (2, 'Urban Apparel',  'urban-apparel',  'help@urban.example',     '2025-01-02 08:00:00.000', '2025-01-02 08:00:00.000'),
  (3, 'Kitchen Pro',    'kitchen-pro',    'care@kitchen.example',   '2025-01-03 08:00:00.000', '2025-01-03 08:00:00.000');

-- Categories (parent/child)
INSERT INTO categories(category_id, name, slug, parent_category_id, created_at, updated_at) VALUES
  (1, 'Electronics', 'electronics', NULL, '2025-01-01 00:00:00.000', '2025-01-01 00:00:00.000'),
  (2, 'Phones',      'phones',      1,    '2025-01-01 00:00:00.000', '2025-01-01 00:00:00.000'),
  (3, 'Laptops',     'laptops',     1,    '2025-01-01 00:00:00.000', '2025-01-01 00:00:00.000'),
  (4, 'Clothing',    'clothing',    NULL, '2025-01-01 00:00:00.000', '2025-01-01 00:00:00.000'),
  (5, 'Cookware',    'cookware',    NULL, '2025-01-01 00:00:00.000', '2025-01-01 00:00:00.000');

-- Products
INSERT INTO products(product_id, vendor_id, sku, name, description, price, currency, is_active, created_at, updated_at) VALUES
  (1, 1, 'ACM-PHN-001', 'Acme Phone X',        '5G smartphone with OLED display', 699.00, 'USD', TRUE, '2025-01-05 09:00:00.000', '2025-01-05 09:00:00.000'),
  (2, 1, 'ACM-LAP-002', 'Acme Laptop Air',     'Lightweight laptop for everyday work', 999.00, 'USD', TRUE, '2025-01-05 09:05:00.000', '2025-01-05 09:05:00.000'),
  (3, 2, 'URB-TSH-010', 'Urban T-Shirt',       'Cotton t-shirt', 19.99, 'USD', TRUE, '2025-01-05 10:00:00.000', '2025-01-05 10:00:00.000'),
  (4, 2, 'URB-JKT-011', 'Urban Jacket',        'Lightweight jacket', 79.50, 'USD', TRUE, '2025-01-05 10:10:00.000', '2025-01-05 10:10:00.000'),
  (5, 3, 'KIT-PAN-100', 'KitchenPro Fry Pan',  'Non-stick 28cm fry pan', 34.95, 'USD', TRUE, '2025-01-06 11:00:00.000', '2025-01-06 11:00:00.000'),
  (6, 3, 'KIT-KNF-200', 'KitchenPro Knife Set','Stainless steel knife set (6 pcs)', 59.00, 'USD', TRUE, '2025-01-06 11:10:00.000', '2025-01-06 11:10:00.000');

-- Product <-> Category mapping
INSERT INTO product_category_map(product_id, category_id, created_at) VALUES
  (1, 2, '2025-01-05 09:10:00.000'),
  (2, 3, '2025-01-05 09:10:00.000'),
  (3, 4, '2025-01-05 10:20:00.000'),
  (4, 4, '2025-01-05 10:20:00.000'),
  (5, 5, '2025-01-06 11:20:00.000'),
  (6, 5, '2025-01-06 11:20:00.000');

-- Product images
INSERT INTO product_images(image_id, product_id, url, alt_text, sort_order, created_at) VALUES
  (1, 1, 'https://cdn.example.com/products/acm-phone-x/front.jpg', 'Acme Phone X front', 1, '2025-01-05 09:15:00.000'),
  (2, 1, 'https://cdn.example.com/products/acm-phone-x/back.jpg',  'Acme Phone X back',  2, '2025-01-05 09:16:00.000'),
  (3, 2, 'https://cdn.example.com/products/acm-laptop-air/front.jpg','Acme Laptop Air',   1, '2025-01-05 09:20:00.000'),
  (4, 3, 'https://cdn.example.com/products/urban-tshirt/blue.jpg',  'Urban T-Shirt',      1, '2025-01-05 10:30:00.000'),
  (5, 5, 'https://cdn.example.com/products/kitchenpro-pan/main.jpg','KitchenPro Fry Pan', 1, '2025-01-06 11:30:00.000');

-- Carts
INSERT INTO carts(cart_id, customer_id, status, created_at, updated_at) VALUES
  (1, 1, 'ORDERED',  '2025-01-13 08:00:00.000', '2025-01-13 09:00:00.000'),
  (2, 2, 'ACTIVE',   '2025-01-14 10:00:00.000', '2025-01-14 10:05:00.000'),
  (3, 3, 'ABANDONED','2025-01-15 18:00:00.000', '2025-01-15 18:30:00.000');

INSERT INTO cart_items(cart_id, product_id, quantity, unit_price, added_at) VALUES
  (1, 1, 1, 699.00, '2025-01-13 08:10:00.000'),
  (1, 3, 2, 19.99,  '2025-01-13 08:12:00.000'),
  (2, 5, 1, 34.95,  '2025-01-14 10:02:00.000'),
  (2, 6, 1, 59.00,  '2025-01-14 10:03:00.000'),
  (3, 4, 1, 79.50,  '2025-01-15 18:05:00.000');

-- Orders
INSERT INTO orders(order_id, customer_id, shipping_address_id, billing_address_id, order_number, status, currency,
                   subtotal, shipping_fee, tax_amount, total_amount, created_at, updated_at) VALUES
  (1, 1, 1, 1, 'ORD-20250113-0001', 'PAID',     'USD', 738.98, 9.99, 61.50, 810.47, '2025-01-13 09:00:00.000', '2025-01-13 09:05:00.000'),
  (2, 2, 3, 3, 'ORD-20250114-0002', 'PENDING',  'USD', 93.95,  4.99,  7.52, 106.46, '2025-01-14 11:00:00.000', '2025-01-14 11:00:00.000'),
  (3, 3, 4, 4, 'ORD-20250116-0003', 'SHIPPED',  'USD', 79.50,  6.99,  0.00,  86.49, '2025-01-16 09:00:00.000', '2025-01-16 12:00:00.000');

-- Order items
INSERT INTO order_items(order_item_id, order_id, line_number, product_id, sku, product_name, quantity, unit_price, created_at) VALUES
  (1, 1, 1, 1, 'ACM-PHN-001', 'Acme Phone X',       1, 699.00, '2025-01-13 09:00:10.000'),
  (2, 1, 2, 3, 'URB-TSH-010', 'Urban T-Shirt',      2, 19.99,  '2025-01-13 09:00:10.000'),
  (3, 2, 1, 5, 'KIT-PAN-100', 'KitchenPro Fry Pan', 1, 34.95,  '2025-01-14 11:00:10.000'),
  (4, 2, 2, 6, 'KIT-KNF-200', 'KitchenPro Knife Set',1, 59.00, '2025-01-14 11:00:10.000'),
  (5, 3, 1, 4, 'URB-JKT-011', 'Urban Jacket',       1, 79.50,  '2025-01-16 09:00:10.000');

-- Payments (unique per provider transaction)
INSERT INTO payments(payment_id, order_id, provider, provider_transaction_id, status, amount, currency, created_at) VALUES
  (1, 1, 'stripe', 'pi_0001', 'CAPTURED', 810.47, 'USD', '2025-01-13 09:02:00.000'),
  (2, 2, 'stripe', 'pi_0002', 'INITIATED',106.46, 'USD', '2025-01-14 11:01:00.000'),
  (3, 3, 'paypal', 'tx_1001', 'CAPTURED', 86.49,  'USD', '2025-01-16 09:05:00.000');

-- Shipments
INSERT INTO shipments(shipment_id, order_id, carrier, tracking_number, status, shipped_at, delivered_at, created_at, updated_at) VALUES
  (1, 1, 'UPS',   '1Z999AA10123456784', 'DELIVERED', '2025-01-14 15:00:00.000', '2025-01-16 11:00:00.000', '2025-01-13 12:00:00.000', '2025-01-16 11:00:00.000'),
  (2, 3, 'DHL',   'JD014600006281000000', 'SHIPPED', '2025-01-16 12:00:00.000', NULL,                   '2025-01-16 12:00:00.000', '2025-01-16 12:00:00.000');

-- Shipment items (map to order_items)
INSERT INTO shipment_items(shipment_item_id, shipment_id, order_item_id, quantity, created_at) VALUES
  (1, 1, 1, 1, '2025-01-13 12:10:00.000'),
  (2, 1, 2, 2, '2025-01-13 12:10:00.000'),
  (3, 2, 5, 1, '2025-01-16 12:10:00.000');

-- ------------------------------
-- Additional sample data
-- ------------------------------

-- More customers
INSERT INTO customers(customer_id, email, full_name, phone, created_at, updated_at) VALUES
  (4, 'diana@example.com', 'Diana Patel', '+1-555-0404', '2025-01-18 08:20:00.000', '2025-01-18 08:20:00.000'),
  (5, 'eric@example.com',  'Eric Miller', '+1-555-0505', '2025-01-19 16:45:00.000', '2025-01-19 16:45:00.000');

INSERT INTO customer_addresses(address_id, customer_id, label, line1, line2, city, state_region, postal_code, country_code, is_default, created_at, updated_at) VALUES
  (5, 4, 'Home', '900 Sunset Blvd', NULL, 'Los Angeles', 'CA', '90028', 'US', TRUE, '2025-01-18 08:25:00.000', '2025-01-18 08:25:00.000'),
  (6, 5, 'Home', '44 Lakeshore Dr', NULL, 'Austin',      'TX', '78701', 'US', TRUE, '2025-01-19 16:50:00.000', '2025-01-19 16:50:00.000');

-- More categories
INSERT INTO categories(category_id, name, slug, parent_category_id, created_at, updated_at) VALUES
  (6, 'Accessories', 'accessories', 1, '2025-01-02 00:00:00.000', '2025-01-02 00:00:00.000'),
  (7, 'Hats',        'hats',        4, '2025-01-02 00:00:00.000', '2025-01-02 00:00:00.000');

-- More products
INSERT INTO products(product_id, vendor_id, sku, name, description, price, currency, is_active, created_at, updated_at) VALUES
  (7, 1, 'ACM-ACC-050', 'Acme USB-C Charger', '65W USB-C fast charger', 29.99, 'USD', TRUE, '2025-01-07 09:00:00.000', '2025-01-07 09:00:00.000'),
  (8, 2, 'URB-HAT-020', 'Urban Cap',         'Adjustable baseball cap', 14.50, 'USD', TRUE, '2025-01-07 10:00:00.000', '2025-01-07 10:00:00.000'),
  (9, 3, 'KIT-SPT-300', 'KitchenPro Spatula','Heat-resistant silicone spatula', 9.90, 'USD', TRUE, '2025-01-08 11:00:00.000', '2025-01-08 11:00:00.000');

INSERT INTO product_category_map(product_id, category_id, created_at) VALUES
  (7, 6, '2025-01-07 09:05:00.000'),
  (8, 7, '2025-01-07 10:05:00.000'),
  (9, 5, '2025-01-08 11:05:00.000');

INSERT INTO product_images(image_id, product_id, url, alt_text, sort_order, created_at) VALUES
  (6, 7, 'https://cdn.example.com/products/acm-usbc-charger/main.jpg', 'Acme USB-C Charger', 1, '2025-01-07 09:10:00.000'),
  (7, 8, 'https://cdn.example.com/products/urban-cap/main.jpg',        'Urban Cap',         1, '2025-01-07 10:10:00.000'),
  (8, 9, 'https://cdn.example.com/products/kitchenpro-spatula/main.jpg','KitchenPro Spatula',1, '2025-01-08 11:10:00.000');

-- More carts and cart items
INSERT INTO carts(cart_id, customer_id, status, created_at, updated_at) VALUES
  (4, 4, 'ORDERED', '2025-01-20 10:00:00.000', '2025-01-20 10:30:00.000'),
  (5, 5, 'ACTIVE',  '2025-01-21 13:00:00.000', '2025-01-21 13:05:00.000');

INSERT INTO cart_items(cart_id, product_id, quantity, unit_price, added_at) VALUES
  (4, 2, 1, 999.00, '2025-01-20 10:05:00.000'),
  (4, 7, 1, 29.99,  '2025-01-20 10:06:00.000'),
  (4, 9, 3, 9.90,   '2025-01-20 10:07:00.000'),
  (5, 8, 2, 14.50,  '2025-01-21 13:02:00.000');

-- More orders
INSERT INTO orders(order_id, customer_id, shipping_address_id, billing_address_id, order_number, status, currency,
                   subtotal, shipping_fee, tax_amount, total_amount, created_at, updated_at) VALUES
  (4, 4, 5, 5, 'ORD-20250120-0004', 'DELIVERED', 'USD', 1058.69, 0.00, 83.20, 1141.89, '2025-01-20 10:30:00.000', '2025-01-23 18:00:00.000');

INSERT INTO order_items(order_item_id, order_id, line_number, product_id, sku, product_name, quantity, unit_price, created_at) VALUES
  (6, 4, 1, 2, 'ACM-LAP-002', 'Acme Laptop Air',      1, 999.00, '2025-01-20 10:30:10.000'),
  (7, 4, 2, 7, 'ACM-ACC-050', 'Acme USB-C Charger',   1, 29.99,  '2025-01-20 10:30:10.000'),
  (8, 4, 3, 9, 'KIT-SPT-300', 'KitchenPro Spatula',   3, 9.90,   '2025-01-20 10:30:10.000');

-- Multiple payments on the same order (e.g., retry): provider_transaction_id stays unique per provider
INSERT INTO payments(payment_id, order_id, provider, provider_transaction_id, status, amount, currency, created_at) VALUES
  (4, 4, 'stripe', 'pi_0003', 'FAILED',    1141.89, 'USD', '2025-01-20 10:31:00.000'),
  (5, 4, 'stripe', 'pi_0004', 'CAPTURED',  1141.89, 'USD', '2025-01-20 10:33:00.000');

-- Shipments for order 4 split into two packages
INSERT INTO shipments(shipment_id, order_id, carrier, tracking_number, status, shipped_at, delivered_at, created_at, updated_at) VALUES
  (3, 4, 'FedEx', '777777777777', 'DELIVERED', '2025-01-21 09:00:00.000', '2025-01-23 16:00:00.000', '2025-01-20 12:00:00.000', '2025-01-23 16:00:00.000'),
  (4, 4, 'FedEx', '888888888888', 'DELIVERED', '2025-01-21 09:30:00.000', '2025-01-23 18:00:00.000', '2025-01-20 12:05:00.000', '2025-01-23 18:00:00.000');

INSERT INTO shipment_items(shipment_item_id, shipment_id, order_item_id, quantity, created_at) VALUES
  (4, 3, 6, 1, '2025-01-20 12:10:00.000'),
  (5, 3, 7, 1, '2025-01-20 12:10:00.000'),
  (6, 4, 8, 3, '2025-01-20 12:20:00.000');
