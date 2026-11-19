-- Name: Pratik Paul
-- Employee Id: 10859597

DROP DATABASE IF EXISTS food_delivery_db;
CREATE DATABASE food_delivery_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE food_delivery_db;

CREATE TABLE customer (
    customer_id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    full_name       VARCHAR(100) NOT NULL,
    email           VARCHAR(120) NOT NULL,
    mobile          CHAR(10)     NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    is_deleted      TINYINT(1)   NOT NULL DEFAULT 0,
    created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_customer_email  UNIQUE (email),
    CONSTRAINT uq_customer_mobile UNIQUE (mobile),
    CONSTRAINT chk_customer_mobile CHECK (mobile REGEXP '^[6-9][0-9]{9}$')
) ENGINE=InnoDB;

CREATE TABLE customer_address (
    address_id    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_id   INT UNSIGNED NOT NULL,
    label         VARCHAR(30)  NOT NULL DEFAULT 'Home',
    address_line  VARCHAR(200) NOT NULL,
    city          VARCHAR(60)  NOT NULL,
    pincode       CHAR(6)      NOT NULL,
    is_default    TINYINT(1)   NOT NULL DEFAULT 0,
    CONSTRAINT fk_addr_customer FOREIGN KEY (customer_id)
        REFERENCES customer(customer_id) ON DELETE CASCADE,
    CONSTRAINT chk_pincode CHECK (pincode REGEXP '^[0-9]{6}$')
) ENGINE=InnoDB;

CREATE UNIQUE INDEX uq_one_default_address
    ON customer_address ((CASE WHEN is_default = 1 THEN customer_id END));

CREATE TABLE restaurant_owner (
    owner_id    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    full_name   VARCHAR(100) NOT NULL,
    email       VARCHAR(120) NOT NULL UNIQUE,
    mobile      CHAR(10)     NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE restaurant (
    restaurant_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    owner_id        INT UNSIGNED NOT NULL,
    name            VARCHAR(120) NOT NULL,
    address_line    VARCHAR(200) NOT NULL,
    city            VARCHAR(60)  NOT NULL,
    pincode         CHAR(6)      NOT NULL,
    contact_number  CHAR(10)     NOT NULL,
    email           VARCHAR(120) NOT NULL,
    opening_time    TIME         NOT NULL,
    closing_time    TIME         NOT NULL,
    is_active       TINYINT(1)   NOT NULL DEFAULT 1,
    CONSTRAINT fk_rest_owner FOREIGN KEY (owner_id) REFERENCES restaurant_owner(owner_id),
    CONSTRAINT uq_rest_email UNIQUE (email),
    CONSTRAINT uq_rest_name_addr UNIQUE (name, address_line, city)
) ENGINE=InnoDB;

CREATE TABLE food_category (
    category_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE menu_item (
    item_id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    restaurant_id  INT UNSIGNED NOT NULL,
    category_id    INT UNSIGNED NOT NULL,
    item_name      VARCHAR(100) NOT NULL,
    description    VARCHAR(255),
    price          DECIMAL(8,2) NOT NULL,
    is_veg         TINYINT(1)   NOT NULL,
    is_available   TINYINT(1)   NOT NULL DEFAULT 1,
    CONSTRAINT fk_item_rest FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id),
    CONSTRAINT fk_item_cat  FOREIGN KEY (category_id)   REFERENCES food_category(category_id),
    CONSTRAINT uq_item_per_rest UNIQUE (restaurant_id, item_name),
    CONSTRAINT chk_item_price CHECK (price > 0)
) ENGINE=InnoDB;

CREATE TABLE menu_item_price_history (
    history_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    item_id      INT UNSIGNED NOT NULL,
    old_price    DECIMAL(8,2) NOT NULL,
    new_price    DECIMAL(8,2) NOT NULL,
    changed_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ph_item FOREIGN KEY (item_id) REFERENCES menu_item(item_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE cart (
    cart_id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_id    INT UNSIGNED NOT NULL,
    restaurant_id  INT UNSIGNED NULL,
    updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_cart_customer UNIQUE (customer_id),
    CONSTRAINT fk_cart_customer FOREIGN KEY (customer_id) REFERENCES customer(customer_id) ON DELETE CASCADE,
    CONSTRAINT fk_cart_rest FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id)
) ENGINE=InnoDB;

CREATE TABLE cart_item (
    cart_id   INT UNSIGNED NOT NULL,
    item_id   INT UNSIGNED NOT NULL,
    quantity  SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (cart_id, item_id),
    CONSTRAINT fk_ci_cart FOREIGN KEY (cart_id) REFERENCES cart(cart_id) ON DELETE CASCADE,
    CONSTRAINT fk_ci_item FOREIGN KEY (item_id) REFERENCES menu_item(item_id),
    CONSTRAINT chk_ci_qty CHECK (quantity BETWEEN 1 AND 50)
) ENGINE=InnoDB;

CREATE TABLE coupon (
    coupon_id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code                 VARCHAR(20)  NOT NULL UNIQUE,
    discount_type        ENUM('PERCENT','FIXED') NOT NULL,
    discount_value       DECIMAL(8,2) NOT NULL,
    max_discount_amount  DECIMAL(8,2) NULL,
    min_order_value      DECIMAL(8,2) NOT NULL DEFAULT 0,
    valid_from           DATE NOT NULL,
    valid_to             DATE NOT NULL,
    usage_limit_per_user TINYINT UNSIGNED NOT NULL DEFAULT 1,
    total_usage_limit    INT UNSIGNED NULL,
    is_active            TINYINT(1) NOT NULL DEFAULT 1,
    CONSTRAINT chk_coupon_value CHECK (discount_value > 0),
    CONSTRAINT chk_coupon_pct   CHECK (discount_type <> 'PERCENT' OR discount_value <= 100),
    CONSTRAINT chk_coupon_dates CHECK (valid_to >= valid_from)
) ENGINE=InnoDB;

CREATE TABLE delivery_partner (
    partner_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    full_name       VARCHAR(100) NOT NULL,
    mobile          CHAR(10)     NOT NULL UNIQUE,
    vehicle_type    ENUM('BIKE','SCOOTER','BICYCLE','EV') NOT NULL,
    vehicle_number  VARCHAR(15)  NULL UNIQUE,
    availability    ENUM('AVAILABLE','BUSY','OFFLINE') NOT NULL DEFAULT 'OFFLINE'
) ENGINE=InnoDB;

CREATE TABLE orders (
    order_id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_id      INT UNSIGNED NOT NULL,
    restaurant_id    INT UNSIGNED NOT NULL,
    address_id       INT UNSIGNED NOT NULL,
    coupon_id        INT UNSIGNED NULL,
    order_datetime   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status           ENUM('PLACED','CONFIRMED','PREPARING','READY_FOR_PICKUP',
                          'OUT_FOR_DELIVERY','DELIVERED','CANCELLED') NOT NULL DEFAULT 'PLACED',
    subtotal         DECIMAL(10,2) NOT NULL,
    delivery_charge  DECIMAL(8,2)  NOT NULL DEFAULT 0,
    discount_amount  DECIMAL(8,2)  NOT NULL DEFAULT 0,
    final_amount     DECIMAL(10,2) NOT NULL,
    estimated_delivery_time DATETIME NULL,
    cancel_reason    VARCHAR(255) NULL,
    cancelled_at     DATETIME NULL,
    CONSTRAINT fk_ord_cust  FOREIGN KEY (customer_id)   REFERENCES customer(customer_id),
    CONSTRAINT fk_ord_rest  FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id),
    CONSTRAINT fk_ord_addr  FOREIGN KEY (address_id)    REFERENCES customer_address(address_id),
    CONSTRAINT fk_ord_coupon FOREIGN KEY (coupon_id)    REFERENCES coupon(coupon_id),
    CONSTRAINT chk_ord_amounts CHECK (subtotal >= 0 AND delivery_charge >= 0 AND discount_amount >= 0
                                      AND discount_amount <= subtotal),
    CONSTRAINT chk_ord_final CHECK (final_amount = subtotal + delivery_charge - discount_amount),
    CONSTRAINT chk_ord_cancel CHECK (status <> 'CANCELLED' OR cancel_reason IS NOT NULL)
) ENGINE=InnoDB;

CREATE TABLE order_item (
    order_id    INT UNSIGNED NOT NULL,
    item_id     INT UNSIGNED NOT NULL,
    quantity    SMALLINT UNSIGNED NOT NULL,
    unit_price  DECIMAL(8,2) NOT NULL,
    PRIMARY KEY (order_id, item_id),
    CONSTRAINT fk_oi_order FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    CONSTRAINT fk_oi_item  FOREIGN KEY (item_id)  REFERENCES menu_item(item_id),
    CONSTRAINT chk_oi_qty   CHECK (quantity > 0),
    CONSTRAINT chk_oi_price CHECK (unit_price > 0)
) ENGINE=InnoDB;

CREATE TABLE order_status_history (
    history_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id     INT UNSIGNED NOT NULL,
    status       ENUM('PLACED','CONFIRMED','PREPARING','READY_FOR_PICKUP',
                      'OUT_FOR_DELIVERY','DELIVERED','CANCELLED') NOT NULL,
    changed_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_osh_order FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE coupon_redemption (
    redemption_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    coupon_id      INT UNSIGNED NOT NULL,
    customer_id    INT UNSIGNED NOT NULL,
    order_id       INT UNSIGNED NOT NULL UNIQUE,
    discount_given DECIMAL(8,2) NOT NULL,
    redeemed_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_cr_coupon FOREIGN KEY (coupon_id)   REFERENCES coupon(coupon_id),
    CONSTRAINT fk_cr_cust   FOREIGN KEY (customer_id) REFERENCES customer(customer_id),
    CONSTRAINT fk_cr_order  FOREIGN KEY (order_id)    REFERENCES orders(order_id)
) ENGINE=InnoDB;

CREATE TABLE payment (
    payment_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id         INT UNSIGNED NOT NULL,
    method           ENUM('UPI','CREDIT_CARD','DEBIT_CARD','COD') NOT NULL,
    amount           DECIMAL(10,2) NOT NULL,
    status           ENUM('PENDING','SUCCESS','FAILED','REFUNDED') NOT NULL DEFAULT 'PENDING',
    transaction_ref  VARCHAR(40) NULL,
    payment_datetime DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_pay_order FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT uq_pay_txn UNIQUE (transaction_ref),
    CONSTRAINT chk_pay_amount CHECK (amount > 0)
) ENGINE=InnoDB;

CREATE TABLE refund (
    refund_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    payment_id     INT UNSIGNED NOT NULL,
    order_id       INT UNSIGNED NOT NULL,
    refund_amount  DECIMAL(10,2) NOT NULL,
    reason         VARCHAR(255) NOT NULL,
    status         ENUM('INITIATED','COMPLETED','FAILED') NOT NULL DEFAULT 'INITIATED',
    refunded_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ref_pay   FOREIGN KEY (payment_id) REFERENCES payment(payment_id),
    CONSTRAINT fk_ref_order FOREIGN KEY (order_id)   REFERENCES orders(order_id),
    CONSTRAINT chk_ref_amt  CHECK (refund_amount > 0)
) ENGINE=InnoDB;

CREATE TABLE delivery (
    delivery_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id         INT UNSIGNED NOT NULL,
    partner_id       INT UNSIGNED NOT NULL,
    assignment_status ENUM('ASSIGNED','ACCEPTED','REJECTED') NOT NULL DEFAULT 'ASSIGNED',
    delivery_status  ENUM('PENDING','PICKED_UP','DELIVERED','FAILED') NOT NULL DEFAULT 'PENDING',
    assigned_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    pickup_time      DATETIME NULL,
    delivery_time    DATETIME NULL,
    CONSTRAINT fk_del_order   FOREIGN KEY (order_id)   REFERENCES orders(order_id),
    CONSTRAINT fk_del_partner FOREIGN KEY (partner_id) REFERENCES delivery_partner(partner_id),
    CONSTRAINT chk_del_times  CHECK (pickup_time IS NULL OR delivery_time IS NULL OR delivery_time >= pickup_time)
) ENGINE=InnoDB;

CREATE TABLE review (
    review_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id       INT UNSIGNED NOT NULL,
    customer_id    INT UNSIGNED NOT NULL,
    restaurant_id  INT UNSIGNED NOT NULL,
    rating         TINYINT UNSIGNED NOT NULL,
    comment        VARCHAR(500),
    created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_review_order UNIQUE (order_id),
    CONSTRAINT fk_rev_order FOREIGN KEY (order_id)      REFERENCES orders(order_id),
    CONSTRAINT fk_rev_cust  FOREIGN KEY (customer_id)   REFERENCES customer(customer_id),
    CONSTRAINT fk_rev_rest  FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id),
    CONSTRAINT chk_rev_rating CHECK (rating BETWEEN 1 AND 5)
) ENGINE=InnoDB;

CREATE TABLE item_review (
    item_review_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id       INT UNSIGNED NOT NULL,
    item_id        INT UNSIGNED NOT NULL,
    rating         TINYINT UNSIGNED NOT NULL,
    comment        VARCHAR(500),
    CONSTRAINT uq_item_review UNIQUE (order_id, item_id),
    CONSTRAINT fk_ir_oi FOREIGN KEY (order_id, item_id) REFERENCES order_item(order_id, item_id),
    CONSTRAINT chk_ir_rating CHECK (rating BETWEEN 1 AND 5)
) ENGINE=InnoDB;

CREATE INDEX idx_rest_city        ON restaurant (city, is_active);
CREATE INDEX idx_item_rest_avail  ON menu_item (restaurant_id, is_available);
CREATE INDEX idx_item_cat_price   ON menu_item (category_id, price);
CREATE INDEX idx_item_name        ON menu_item (item_name);
CREATE INDEX idx_orders_cust_date ON orders (customer_id, order_datetime);
CREATE INDEX idx_orders_rest_date ON orders (restaurant_id, order_datetime);
CREATE INDEX idx_orders_status    ON orders (status);
CREATE INDEX idx_pay_order        ON payment (order_id);
CREATE INDEX idx_del_partner      ON delivery (partner_id, delivery_status);
CREATE INDEX idx_osh_order        ON order_status_history (order_id, changed_at);
CREATE INDEX idx_cr_coupon_cust   ON coupon_redemption (coupon_id, customer_id);

CREATE VIEW v_restaurant_rating AS
SELECT r.restaurant_id, r.name,
       COUNT(rv.review_id)            AS total_reviews,
       ROUND(AVG(rv.rating), 2)       AS avg_rating
FROM restaurant r
LEFT JOIN review rv ON rv.restaurant_id = r.restaurant_id
GROUP BY r.restaurant_id, r.name;

CREATE VIEW v_order_summary AS
SELECT o.order_id, o.order_datetime, o.status,
       c.customer_id, c.full_name AS customer_name,
       r.restaurant_id, r.name AS restaurant_name,
       o.subtotal, o.delivery_charge, o.discount_amount, o.final_amount
FROM orders o
JOIN customer c   ON c.customer_id   = o.customer_id
JOIN restaurant r ON r.restaurant_id = o.restaurant_id;

CREATE VIEW v_restaurant_monthly_revenue AS
SELECT r.restaurant_id, r.name,
       DATE_FORMAT(o.order_datetime, '%Y-%m') AS month,
       COUNT(*)            AS orders_delivered,
       SUM(o.final_amount) AS revenue
FROM orders o
JOIN restaurant r ON r.restaurant_id = o.restaurant_id
WHERE o.status = 'DELIVERED'
GROUP BY r.restaurant_id, r.name, DATE_FORMAT(o.order_datetime, '%Y-%m');

DELIMITER $$

CREATE TRIGGER trg_review_eligibility BEFORE INSERT ON review
FOR EACH ROW
BEGIN
    DECLARE v_ok INT DEFAULT 0;
    SELECT COUNT(*) INTO v_ok FROM orders
     WHERE order_id = NEW.order_id AND customer_id = NEW.customer_id
       AND restaurant_id = NEW.restaurant_id AND status = 'DELIVERED';
    IF v_ok = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Review allowed only for own, delivered order';
    END IF;
END$$

CREATE TRIGGER trg_order_item_check BEFORE INSERT ON order_item
FOR EACH ROW
BEGIN
    DECLARE v_avail TINYINT; DECLARE v_active TINYINT;
    DECLARE v_open TIME; DECLARE v_close TIME; DECLARE v_odt DATETIME;
    IF @bulk_load IS NULL THEN
    SELECT m.is_available, r.is_active, r.opening_time, r.closing_time, o.order_datetime
      INTO v_avail, v_active, v_open, v_close, v_odt
      FROM menu_item m
      JOIN restaurant r ON r.restaurant_id = m.restaurant_id
      JOIN orders o     ON o.order_id = NEW.order_id
     WHERE m.item_id = NEW.item_id;
    IF v_avail = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Food item is not available';
    END IF;
    IF v_active = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Restaurant is not active';
    END IF;
    IF v_open <= v_close THEN
        IF TIME(v_odt) < v_open OR TIME(v_odt) > v_close THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Restaurant is closed';
        END IF;
    ELSEIF TIME(v_odt) < v_open AND TIME(v_odt) > v_close THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Restaurant is closed';
    END IF;
    END IF;
END$$

CREATE TRIGGER trg_coupon_limit BEFORE INSERT ON coupon_redemption
FOR EACH ROW
BEGIN
    DECLARE v_used INT; DECLARE v_limit INT;
    SELECT COUNT(*) INTO v_used FROM coupon_redemption
     WHERE coupon_id = NEW.coupon_id AND customer_id = NEW.customer_id;
    SELECT usage_limit_per_user INTO v_limit FROM coupon WHERE coupon_id = NEW.coupon_id;
    IF v_used >= v_limit THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Coupon usage limit reached for this customer';
    END IF;
END$$

CREATE TRIGGER trg_price_history AFTER UPDATE ON menu_item
FOR EACH ROW
BEGIN
    IF OLD.price <> NEW.price THEN
        INSERT INTO menu_item_price_history (item_id, old_price, new_price)
        VALUES (OLD.item_id, OLD.price, NEW.price);
    END IF;
END$$

CREATE TRIGGER trg_order_status_upd AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        INSERT INTO order_status_history (order_id, status) VALUES (NEW.order_id, NEW.status);
    END IF;
END$$

DELIMITER ;

USE food_delivery_db;

SET @bulk_load = 1;

INSERT INTO customer (customer_id, full_name, email, mobile, password_hash, created_at) VALUES
  (1, 'Aarav Sharma', 'aarav.sharma@mail.com', '9876500001', '$2b$12$hashed_pw_1', '2026-01-02 10:00:00'),
  (2, 'Priya Nair', 'priya.nair@mail.com', '9876500002', '$2b$12$hashed_pw_2', '2026-01-03 10:00:00'),
  (3, 'Rohan Mehta', 'rohan.mehta@mail.com', '9876500003', '$2b$12$hashed_pw_3', '2026-01-04 10:00:00'),
  (4, 'Sneha Iyer', 'sneha.iyer@mail.com', '9876500004', '$2b$12$hashed_pw_4', '2026-01-05 10:00:00'),
  (5, 'Vikram Singh', 'vikram.singh@mail.com', '9876500005', '$2b$12$hashed_pw_5', '2026-01-06 10:00:00'),
  (6, 'Ananya Das', 'ananya.das@mail.com', '9876500006', '$2b$12$hashed_pw_6', '2026-01-07 10:00:00'),
  (7, 'Karthik Reddy', 'karthik.reddy@mail.com', '9876500007', '$2b$12$hashed_pw_7', '2026-01-08 10:00:00'),
  (8, 'Meera Pillai', 'meera.pillai@mail.com', '9876500008', '$2b$12$hashed_pw_8', '2026-01-09 10:00:00');

INSERT INTO customer_address (address_id, customer_id, label, address_line, city, pincode, is_default) VALUES
  (1, 1, 'Home', '12 MG Road', 'Bengaluru', '560001', 1),
  (2, 1, 'Office', 'Tech Park, Whitefield', 'Bengaluru', '560066', 0),
  (3, 2, 'Home', '45 Anna Nagar', 'Chennai', '600040', 1),
  (4, 3, 'Home', '7 Bandra West', 'Mumbai', '400050', 1),
  (5, 3, 'Office', 'BKC Tower B', 'Mumbai', '400051', 0),
  (6, 4, 'Home', '22 Jubilee Hills', 'Hyderabad', '500033', 1),
  (7, 5, 'Home', '9 Koramangala 4th Block', 'Bengaluru', '560034', 1),
  (8, 6, 'Home', '31 Salt Lake Sector 5', 'Kolkata', '700091', 1),
  (9, 7, 'Home', '18 Indiranagar', 'Bengaluru', '560038', 1),
  (10, 8, 'Home', '5 Kakkanad', 'Kochi', '682030', 1);

INSERT INTO restaurant_owner (owner_id, full_name, email, mobile) VALUES
  (1, 'Suresh Kumar', 'suresh@spicegarden.com', '9811100001'),
  (2, 'Lakshmi Rao', 'lakshmi@dosadelight.com', '9811100002'),
  (3, 'Wei Chen', 'wei@dragonwok.com', '9811100003'),
  (4, 'Imran Khan', 'imran@burgerbarn.com', '9811100004'),
  (5, 'Deepa Joshi', 'deepa@sweettooth.com', '9811100005');

INSERT INTO restaurant (restaurant_id, owner_id, name, address_line, city, pincode, contact_number, email, opening_time, closing_time, is_active) VALUES
  (1, 1, 'Spice Garden', '10 Residency Road', 'Bengaluru', '560025', '8022000001', 'contact@spicegarden.com', '10:00:00', '23:00:00', 1),
  (2, 2, 'Dosa Delight', '3 Church Street', 'Bengaluru', '560001', '8022000002', 'contact@dosadelight.com', '07:00:00', '22:00:00', 1),
  (3, 3, 'Dragon Wok', '8 Brigade Road', 'Bengaluru', '560001', '8022000003', 'contact@dragonwok.com', '11:00:00', '23:30:00', 1),
  (4, 4, 'Burger Barn', '14 Indiranagar 100ft Rd', 'Bengaluru', '560038', '8022000004', 'contact@burgerbarn.com', '11:00:00', '23:59:00', 1),
  (5, 5, 'Sweet Tooth', '6 Koramangala 5th Block', 'Bengaluru', '560095', '8022000005', 'contact@sweettooth.com', '09:00:00', '21:00:00', 0);

INSERT INTO food_category (category_id, category_name) VALUES
  (1, 'South Indian'),
  (2, 'North Indian'),
  (3, 'Chinese'),
  (4, 'Fast Food'),
  (5, 'Desserts'),
  (6, 'Beverages');

INSERT INTO menu_item (item_id, restaurant_id, category_id, item_name, description, price, is_veg, is_available) VALUES
  (1, 1, 2, 'Paneer Butter Masala', 'Creamy tomato gravy with paneer', 280.0, 1, 1),
  (2, 1, 2, 'Butter Chicken', 'Classic tandoori chicken in butter gravy', 340.0, 0, 1),
  (3, 1, 2, 'Garlic Naan', 'Tandoor-baked garlic bread', 60.0, 1, 1),
  (4, 1, 2, 'Dal Makhani', 'Slow cooked black lentils', 220.0, 1, 1),
  (5, 1, 2, 'Chicken Biryani', 'Hyderabadi style dum biryani', 320.0, 0, 1),
  (6, 1, 6, 'Sweet Lassi', 'Chilled yoghurt drink', 90.0, 1, 1),
  (7, 2, 1, 'Masala Dosa', 'Crispy dosa with potato filling', 120.0, 1, 1),
  (8, 2, 1, 'Idli Sambar (3 pcs)', 'Steamed rice cakes with sambar', 80.0, 1, 1),
  (9, 2, 1, 'Medu Vada (2 pcs)', 'Fried lentil doughnuts', 70.0, 1, 1),
  (10, 2, 1, 'Filter Coffee', 'South Indian filter coffee', 50.0, 1, 1),
  (11, 2, 1, 'Rava Dosa', 'Crispy semolina dosa', 130.0, 1, 0),
  (12, 3, 3, 'Veg Hakka Noodles', 'Wok tossed noodles', 180.0, 1, 1),
  (13, 3, 3, 'Chicken Manchurian', 'Fried chicken in manchurian sauce', 260.0, 0, 1),
  (14, 3, 3, 'Veg Fried Rice', 'Classic fried rice', 170.0, 1, 1),
  (15, 3, 3, 'Chilli Paneer', 'Spicy paneer stir fry', 240.0, 1, 1),
  (16, 3, 3, 'Schezwan Chicken Noodles', 'Spicy chicken noodles', 230.0, 0, 1),
  (17, 4, 4, 'Classic Veg Burger', 'Veg patty with fresh veggies', 150.0, 1, 1),
  (18, 4, 4, 'Chicken Cheese Burger', 'Grilled chicken with cheese', 210.0, 0, 1),
  (19, 4, 4, 'French Fries', 'Salted crispy fries', 100.0, 1, 1),
  (20, 4, 4, 'Chicken Wings (6 pcs)', 'Hot and spicy wings', 250.0, 0, 1),
  (21, 4, 6, 'Cold Coffee', 'Iced blended coffee', 120.0, 1, 1),
  (22, 5, 5, 'Chocolate Truffle Cake', 'Rich chocolate cake slice', 180.0, 1, 1),
  (23, 5, 5, 'Gulab Jamun (2 pcs)', 'Milk dumplings in sugar syrup', 90.0, 1, 1),
  (24, 5, 5, 'Rasmalai (2 pcs)', 'Cottage cheese in saffron milk', 130.0, 1, 1);

INSERT INTO coupon (coupon_id, code, discount_type, discount_value, max_discount_amount, min_order_value, valid_from, valid_to, usage_limit_per_user, total_usage_limit, is_active) VALUES
  (1, 'WELCOME50', 'PERCENT', 50.0, 100.0, 200.0, '2026-01-01', '2026-12-31', 1, 1000, 1),
  (2, 'FLAT75', 'FIXED', 75.0, NULL, 400.0, '2026-03-01', '2026-12-31', 3, 500, 1),
  (3, 'FEAST20', 'PERCENT', 20.0, 150.0, 500.0, '2026-06-01', '2026-09-30', 2, 300, 1);

INSERT INTO delivery_partner (partner_id, full_name, mobile, vehicle_type, vehicle_number, availability) VALUES
  (1, 'Ravi Kumar', '9700000001', 'BIKE', 'KA01AB1234', 'AVAILABLE'),
  (2, 'Arjun Patel', '9700000002', 'SCOOTER', 'KA05CD5678', 'BUSY'),
  (3, 'Mohammed Ali', '9700000003', 'BIKE', 'KA03EF9012', 'AVAILABLE'),
  (4, 'Sunil Yadav', '9700000004', 'EV', 'KA02GH3456', 'OFFLINE'),
  (5, 'Deepak Gowda', '9700000005', 'BICYCLE', NULL, 'AVAILABLE'),
  (6, 'Faisal Khan', '9700000006', 'SCOOTER', 'KA04JK7890', 'AVAILABLE');

INSERT INTO orders (order_id, customer_id, restaurant_id, address_id, coupon_id, order_datetime, status, subtotal, delivery_charge, discount_amount, final_amount, estimated_delivery_time, cancel_reason, cancelled_at) VALUES
  (1, 1, 1, 1, NULL, '2026-08-03 13:10:00', 'DELIVERED', 490.0, 40, 0.0, 530.0, '2026-08-03 13:55:00', NULL, NULL),
  (2, 1, 2, 1, NULL, '2026-08-10 08:30:00', 'DELIVERED', 340.0, 30, 0.0, 370.0, '2026-08-10 09:15:00', NULL, NULL),
  (3, 1, 1, 2, 1, '2026-09-05 20:15:00', 'DELIVERED', 780.0, 40, 100.0, 720.0, '2026-09-05 21:00:00', NULL, NULL),
  (4, 2, 2, 3, NULL, '2026-08-12 09:00:00', 'DELIVERED', 200.0, 30, 0.0, 230.0, '2026-08-12 09:45:00', NULL, NULL),
  (5, 2, 3, 3, 2, '2026-09-14 19:30:00', 'DELIVERED', 680.0, 45, 75.0, 650.0, '2026-09-14 20:15:00', NULL, NULL),
  (6, 3, 4, 4, NULL, '2026-08-20 21:00:00', 'DELIVERED', 740.0, 35, 0.0, 775.0, '2026-08-20 21:45:00', NULL, NULL),
  (7, 3, 1, 5, 3, '2026-07-18 20:00:00', 'DELIVERED', 1140.0, 40, 150.0, 1030.0, '2026-07-18 20:45:00', NULL, NULL),
  (8, 3, 4, 4, NULL, '2026-09-22 22:10:00', 'DELIVERED', 460.0, 35, 0.0, 495.0, '2026-09-22 22:55:00', NULL, NULL),
  (9, 4, 3, 6, NULL, '2026-10-02 13:45:00', 'DELIVERED', 530.0, 45, 0.0, 575.0, '2026-10-02 14:30:00', NULL, NULL),
  (10, 4, 1, 6, NULL, '2026-10-15 12:30:00', 'CANCELLED', 320.0, 40, 0.0, 360.0, '2026-10-15 13:15:00', 'Customer changed mind', '2026-10-15 12:35:00'),
  (11, 5, 2, 7, NULL, '2026-08-25 08:15:00', 'DELIVERED', 430.0, 30, 0.0, 460.0, '2026-08-25 09:00:00', NULL, NULL),
  (12, 5, 4, 7, 2, '2026-10-08 20:45:00', 'DELIVERED', 640.0, 35, 75.0, 600.0, '2026-10-08 21:30:00', NULL, NULL),
  (13, 5, 1, 7, NULL, '2026-10-20 13:00:00', 'DELIVERED', 340.0, 40, 0.0, 380.0, '2026-10-20 13:45:00', NULL, NULL),
  (14, 6, 3, 8, NULL, '2026-09-02 12:20:00', 'DELIVERED', 400.0, 45, 0.0, 445.0, '2026-09-02 13:05:00', NULL, NULL),
  (15, 6, 2, 8, NULL, '2026-10-11 09:10:00', 'CANCELLED', 120.0, 30, 0.0, 150.0, '2026-10-11 09:55:00', 'Restaurant rejected the order', '2026-10-11 09:15:00'),
  (16, 7, 1, 9, NULL, '2026-10-25 19:50:00', 'DELIVERED', 820.0, 40, 0.0, 860.0, '2026-10-25 20:35:00', NULL, NULL),
  (17, 7, 4, 9, NULL, '2026-10-28 21:30:00', 'OUT_FOR_DELIVERY', 270.0, 35, 0.0, 305.0, '2026-10-28 22:15:00', NULL, NULL),
  (18, 2, 1, 3, NULL, '2026-11-05 13:30:00', 'DELIVERED', 620.0, 40, 0.0, 660.0, '2026-11-05 14:15:00', NULL, NULL),
  (19, 1, 3, 1, NULL, '2026-11-08 20:00:00', 'PREPARING', 420.0, 45, 0.0, 465.0, '2026-11-08 20:45:00', NULL, NULL),
  (20, 3, 2, 4, NULL, '2026-11-09 08:45:00', 'DELIVERED', 210.0, 30, 0.0, 240.0, '2026-11-09 09:30:00', NULL, NULL),
  (21, 2, 1, 3, NULL, '2026-11-10 12:30:00', 'DELIVERED', 380.0, 40, 0.0, 420.0, '2026-11-10 13:15:00', NULL, NULL),
  (22, 4, 1, 6, NULL, '2026-11-11 13:00:00', 'DELIVERED', 460.0, 40, 0.0, 500.0, '2026-11-11 13:45:00', NULL, NULL),
  (23, 6, 3, 8, NULL, '2026-11-11 20:00:00', 'DELIVERED', 430.0, 45, 0.0, 475.0, '2026-11-11 20:45:00', NULL, NULL),
  (24, 7, 2, 9, NULL, '2026-11-12 09:00:00', 'DELIVERED', 290.0, 30, 0.0, 320.0, '2026-11-12 09:45:00', NULL, NULL);

INSERT INTO order_item (order_id, item_id, quantity, unit_price) VALUES
  (1, 1, 1, 280.0),
  (1, 3, 2, 60.0),
  (1, 6, 1, 90.0),
  (2, 7, 2, 120.0),
  (2, 10, 2, 50.0),
  (3, 2, 1, 340.0),
  (3, 5, 1, 320.0),
  (3, 3, 2, 60.0),
  (4, 7, 1, 120.0),
  (4, 8, 1, 80.0),
  (5, 12, 1, 180.0),
  (5, 13, 1, 260.0),
  (5, 15, 1, 240.0),
  (6, 17, 2, 150.0),
  (6, 19, 2, 100.0),
  (6, 21, 2, 120.0),
  (7, 2, 2, 340.0),
  (7, 4, 1, 220.0),
  (7, 3, 4, 60.0),
  (8, 18, 1, 210.0),
  (8, 20, 1, 250.0),
  (9, 12, 2, 180.0),
  (9, 14, 1, 170.0),
  (10, 5, 1, 320.0),
  (11, 7, 3, 120.0),
  (11, 9, 1, 70.0),
  (12, 18, 2, 210.0),
  (12, 19, 1, 100.0),
  (12, 21, 1, 120.0),
  (13, 1, 1, 280.0),
  (13, 3, 1, 60.0),
  (14, 16, 1, 230.0),
  (14, 14, 1, 170.0),
  (15, 7, 1, 120.0),
  (16, 5, 2, 320.0),
  (16, 6, 2, 90.0),
  (17, 17, 1, 150.0),
  (17, 21, 1, 120.0),
  (18, 4, 1, 220.0),
  (18, 3, 2, 60.0),
  (18, 1, 1, 280.0),
  (19, 15, 1, 240.0),
  (19, 12, 1, 180.0),
  (20, 8, 2, 80.0),
  (20, 10, 1, 50.0),
  (21, 5, 1, 320.0),
  (21, 3, 1, 60.0),
  (22, 2, 1, 340.0),
  (22, 3, 2, 60.0),
  (23, 13, 1, 260.0),
  (23, 14, 1, 170.0),
  (24, 7, 2, 120.0),
  (24, 10, 1, 50.0);

INSERT INTO order_status_history (order_id, status, changed_at) VALUES
  (1, 'PLACED', '2026-08-03 13:10:00'),
  (1, 'CONFIRMED', '2026-08-03 13:18:00'),
  (1, 'PREPARING', '2026-08-03 13:26:00'),
  (1, 'READY_FOR_PICKUP', '2026-08-03 13:34:00'),
  (1, 'OUT_FOR_DELIVERY', '2026-08-03 13:42:00'),
  (1, 'DELIVERED', '2026-08-03 13:50:00'),
  (2, 'PLACED', '2026-08-10 08:30:00'),
  (2, 'CONFIRMED', '2026-08-10 08:38:00'),
  (2, 'PREPARING', '2026-08-10 08:46:00'),
  (2, 'READY_FOR_PICKUP', '2026-08-10 08:54:00'),
  (2, 'OUT_FOR_DELIVERY', '2026-08-10 09:02:00'),
  (2, 'DELIVERED', '2026-08-10 09:10:00'),
  (3, 'PLACED', '2026-09-05 20:15:00'),
  (3, 'CONFIRMED', '2026-09-05 20:23:00'),
  (3, 'PREPARING', '2026-09-05 20:31:00'),
  (3, 'READY_FOR_PICKUP', '2026-09-05 20:39:00'),
  (3, 'OUT_FOR_DELIVERY', '2026-09-05 20:47:00'),
  (3, 'DELIVERED', '2026-09-05 20:55:00'),
  (4, 'PLACED', '2026-08-12 09:00:00'),
  (4, 'CONFIRMED', '2026-08-12 09:08:00'),
  (4, 'PREPARING', '2026-08-12 09:16:00'),
  (4, 'READY_FOR_PICKUP', '2026-08-12 09:24:00'),
  (4, 'OUT_FOR_DELIVERY', '2026-08-12 09:32:00'),
  (4, 'DELIVERED', '2026-08-12 09:40:00'),
  (5, 'PLACED', '2026-09-14 19:30:00'),
  (5, 'CONFIRMED', '2026-09-14 19:38:00'),
  (5, 'PREPARING', '2026-09-14 19:46:00'),
  (5, 'READY_FOR_PICKUP', '2026-09-14 19:54:00'),
  (5, 'OUT_FOR_DELIVERY', '2026-09-14 20:02:00'),
  (5, 'DELIVERED', '2026-09-14 20:10:00'),
  (6, 'PLACED', '2026-08-20 21:00:00'),
  (6, 'CONFIRMED', '2026-08-20 21:08:00'),
  (6, 'PREPARING', '2026-08-20 21:16:00'),
  (6, 'READY_FOR_PICKUP', '2026-08-20 21:24:00'),
  (6, 'OUT_FOR_DELIVERY', '2026-08-20 21:32:00'),
  (6, 'DELIVERED', '2026-08-20 21:40:00'),
  (7, 'PLACED', '2026-07-18 20:00:00'),
  (7, 'CONFIRMED', '2026-07-18 20:08:00'),
  (7, 'PREPARING', '2026-07-18 20:16:00'),
  (7, 'READY_FOR_PICKUP', '2026-07-18 20:24:00'),
  (7, 'OUT_FOR_DELIVERY', '2026-07-18 20:32:00'),
  (7, 'DELIVERED', '2026-07-18 20:40:00'),
  (8, 'PLACED', '2026-09-22 22:10:00'),
  (8, 'CONFIRMED', '2026-09-22 22:18:00'),
  (8, 'PREPARING', '2026-09-22 22:26:00'),
  (8, 'READY_FOR_PICKUP', '2026-09-22 22:34:00'),
  (8, 'OUT_FOR_DELIVERY', '2026-09-22 22:42:00'),
  (8, 'DELIVERED', '2026-09-22 22:50:00'),
  (9, 'PLACED', '2026-10-02 13:45:00'),
  (9, 'CONFIRMED', '2026-10-02 13:53:00'),
  (9, 'PREPARING', '2026-10-02 14:01:00'),
  (9, 'READY_FOR_PICKUP', '2026-10-02 14:09:00'),
  (9, 'OUT_FOR_DELIVERY', '2026-10-02 14:17:00'),
  (9, 'DELIVERED', '2026-10-02 14:25:00'),
  (10, 'PLACED', '2026-10-15 12:30:00'),
  (10, 'CONFIRMED', '2026-10-15 12:32:00'),
  (10, 'CANCELLED', '2026-10-15 12:35:00'),
  (11, 'PLACED', '2026-08-25 08:15:00'),
  (11, 'CONFIRMED', '2026-08-25 08:23:00'),
  (11, 'PREPARING', '2026-08-25 08:31:00'),
  (11, 'READY_FOR_PICKUP', '2026-08-25 08:39:00'),
  (11, 'OUT_FOR_DELIVERY', '2026-08-25 08:47:00'),
  (11, 'DELIVERED', '2026-08-25 08:55:00'),
  (12, 'PLACED', '2026-10-08 20:45:00'),
  (12, 'CONFIRMED', '2026-10-08 20:53:00'),
  (12, 'PREPARING', '2026-10-08 21:01:00'),
  (12, 'READY_FOR_PICKUP', '2026-10-08 21:09:00'),
  (12, 'OUT_FOR_DELIVERY', '2026-10-08 21:17:00'),
  (12, 'DELIVERED', '2026-10-08 21:25:00'),
  (13, 'PLACED', '2026-10-20 13:00:00'),
  (13, 'CONFIRMED', '2026-10-20 13:08:00'),
  (13, 'PREPARING', '2026-10-20 13:16:00'),
  (13, 'READY_FOR_PICKUP', '2026-10-20 13:24:00'),
  (13, 'OUT_FOR_DELIVERY', '2026-10-20 13:32:00'),
  (13, 'DELIVERED', '2026-10-20 13:40:00'),
  (14, 'PLACED', '2026-09-02 12:20:00'),
  (14, 'CONFIRMED', '2026-09-02 12:28:00'),
  (14, 'PREPARING', '2026-09-02 12:36:00'),
  (14, 'READY_FOR_PICKUP', '2026-09-02 12:44:00'),
  (14, 'OUT_FOR_DELIVERY', '2026-09-02 12:52:00'),
  (14, 'DELIVERED', '2026-09-02 13:00:00'),
  (15, 'PLACED', '2026-10-11 09:10:00'),
  (15, 'CANCELLED', '2026-10-11 09:15:00'),
  (16, 'PLACED', '2026-10-25 19:50:00'),
  (16, 'CONFIRMED', '2026-10-25 19:58:00'),
  (16, 'PREPARING', '2026-10-25 20:06:00'),
  (16, 'READY_FOR_PICKUP', '2026-10-25 20:14:00'),
  (16, 'OUT_FOR_DELIVERY', '2026-10-25 20:22:00'),
  (16, 'DELIVERED', '2026-10-25 20:30:00'),
  (17, 'PLACED', '2026-10-28 21:30:00'),
  (17, 'CONFIRMED', '2026-10-28 21:38:00'),
  (17, 'PREPARING', '2026-10-28 21:46:00'),
  (17, 'READY_FOR_PICKUP', '2026-10-28 21:54:00'),
  (17, 'OUT_FOR_DELIVERY', '2026-10-28 22:02:00'),
  (18, 'PLACED', '2026-11-05 13:30:00'),
  (18, 'CONFIRMED', '2026-11-05 13:38:00'),
  (18, 'PREPARING', '2026-11-05 13:46:00'),
  (18, 'READY_FOR_PICKUP', '2026-11-05 13:54:00'),
  (18, 'OUT_FOR_DELIVERY', '2026-11-05 14:02:00'),
  (18, 'DELIVERED', '2026-11-05 14:10:00'),
  (19, 'PLACED', '2026-11-08 20:00:00'),
  (19, 'CONFIRMED', '2026-11-08 20:08:00'),
  (19, 'PREPARING', '2026-11-08 20:16:00'),
  (20, 'PLACED', '2026-11-09 08:45:00'),
  (20, 'CONFIRMED', '2026-11-09 08:53:00'),
  (20, 'PREPARING', '2026-11-09 09:01:00'),
  (20, 'READY_FOR_PICKUP', '2026-11-09 09:09:00'),
  (20, 'OUT_FOR_DELIVERY', '2026-11-09 09:17:00'),
  (20, 'DELIVERED', '2026-11-09 09:25:00'),
  (21, 'PLACED', '2026-11-10 12:30:00'),
  (21, 'CONFIRMED', '2026-11-10 12:38:00'),
  (21, 'PREPARING', '2026-11-10 12:46:00'),
  (21, 'READY_FOR_PICKUP', '2026-11-10 12:54:00'),
  (21, 'OUT_FOR_DELIVERY', '2026-11-10 13:02:00'),
  (21, 'DELIVERED', '2026-11-10 13:10:00'),
  (22, 'PLACED', '2026-11-11 13:00:00'),
  (22, 'CONFIRMED', '2026-11-11 13:08:00'),
  (22, 'PREPARING', '2026-11-11 13:16:00'),
  (22, 'READY_FOR_PICKUP', '2026-11-11 13:24:00'),
  (22, 'OUT_FOR_DELIVERY', '2026-11-11 13:32:00'),
  (22, 'DELIVERED', '2026-11-11 13:40:00'),
  (23, 'PLACED', '2026-11-11 20:00:00'),
  (23, 'CONFIRMED', '2026-11-11 20:08:00'),
  (23, 'PREPARING', '2026-11-11 20:16:00'),
  (23, 'READY_FOR_PICKUP', '2026-11-11 20:24:00'),
  (23, 'OUT_FOR_DELIVERY', '2026-11-11 20:32:00'),
  (23, 'DELIVERED', '2026-11-11 20:40:00'),
  (24, 'PLACED', '2026-11-12 09:00:00'),
  (24, 'CONFIRMED', '2026-11-12 09:08:00'),
  (24, 'PREPARING', '2026-11-12 09:16:00'),
  (24, 'READY_FOR_PICKUP', '2026-11-12 09:24:00'),
  (24, 'OUT_FOR_DELIVERY', '2026-11-12 09:32:00'),
  (24, 'DELIVERED', '2026-11-12 09:40:00');

INSERT INTO payment (payment_id, order_id, method, amount, status, transaction_ref, payment_datetime) VALUES
  (1, 1, 'CREDIT_CARD', 530.0, 'SUCCESS', 'TXN1001', '2026-08-03 13:11:00'),
  (2, 2, 'DEBIT_CARD', 370.0, 'SUCCESS', 'TXN1002', '2026-08-10 08:31:00'),
  (3, 3, 'UPI', 720.0, 'FAILED', 'TXN1003', '2026-09-05 20:15:00'),
  (4, 3, 'CREDIT_CARD', 720.0, 'SUCCESS', 'TXN1004', '2026-09-05 20:16:00'),
  (5, 4, 'UPI', 230.0, 'SUCCESS', 'TXN1005', '2026-08-12 09:01:00'),
  (6, 5, 'CREDIT_CARD', 650.0, 'SUCCESS', 'TXN1006', '2026-09-14 19:31:00'),
  (7, 6, 'DEBIT_CARD', 775.0, 'SUCCESS', 'TXN1007', '2026-08-20 21:01:00'),
  (8, 7, 'COD', 1030.0, 'SUCCESS', NULL, '2026-07-18 20:01:00'),
  (9, 8, 'UPI', 495.0, 'SUCCESS', 'TXN1009', '2026-09-22 22:11:00'),
  (10, 9, 'CREDIT_CARD', 575.0, 'SUCCESS', 'TXN1010', '2026-10-02 13:46:00'),
  (11, 10, 'DEBIT_CARD', 360.0, 'REFUNDED', 'TXN1011', '2026-10-15 12:31:00'),
  (12, 11, 'COD', 460.0, 'SUCCESS', NULL, '2026-08-25 08:16:00'),
  (13, 12, 'UPI', 600.0, 'FAILED', 'TXN1013', '2026-10-08 20:45:00'),
  (14, 12, 'CREDIT_CARD', 600.0, 'SUCCESS', 'TXN1014', '2026-10-08 20:46:00'),
  (15, 13, 'CREDIT_CARD', 380.0, 'SUCCESS', 'TXN1015', '2026-10-20 13:01:00'),
  (16, 14, 'DEBIT_CARD', 445.0, 'SUCCESS', 'TXN1016', '2026-09-02 12:21:00'),
  (17, 15, 'UPI', 150.0, 'REFUNDED', 'TXN1017', '2026-10-11 09:11:00'),
  (18, 16, 'UPI', 860.0, 'SUCCESS', 'TXN1018', '2026-10-25 19:51:00'),
  (19, 17, 'CREDIT_CARD', 305.0, 'SUCCESS', 'TXN1019', '2026-10-28 21:31:00'),
  (20, 18, 'DEBIT_CARD', 660.0, 'SUCCESS', 'TXN1020', '2026-11-05 13:31:00'),
  (21, 19, 'COD', 465.0, 'PENDING', NULL, '2026-11-08 20:01:00'),
  (22, 20, 'UPI', 240.0, 'SUCCESS', 'TXN1022', '2026-11-09 08:46:00'),
  (23, 21, 'CREDIT_CARD', 420.0, 'SUCCESS', 'TXN1023', '2026-11-10 12:31:00'),
  (24, 22, 'DEBIT_CARD', 500.0, 'SUCCESS', 'TXN1024', '2026-11-11 13:01:00'),
  (25, 23, 'COD', 475.0, 'SUCCESS', NULL, '2026-11-11 20:01:00'),
  (26, 24, 'UPI', 320.0, 'SUCCESS', 'TXN1026', '2026-11-12 09:01:00');

INSERT INTO refund (refund_id, payment_id, order_id, refund_amount, reason, status, refunded_at) VALUES
  (1, 11, 10, 360.0, 'Customer changed mind', 'COMPLETED', '2026-10-15 14:30:00'),
  (2, 17, 15, 150.0, 'Restaurant rejected the order', 'COMPLETED', '2026-10-11 11:10:00');

INSERT INTO coupon_redemption (redemption_id, coupon_id, customer_id, order_id, discount_given, redeemed_at) VALUES
  (1, 1, 1, 3, 100.0, '2026-09-05 20:15:00'),
  (2, 2, 2, 5, 75.0, '2026-09-14 19:30:00'),
  (3, 3, 3, 7, 150.0, '2026-07-18 20:00:00'),
  (4, 2, 5, 12, 75.0, '2026-10-08 20:45:00');

INSERT INTO delivery (delivery_id, order_id, partner_id, assignment_status, delivery_status, assigned_at, pickup_time, delivery_time) VALUES
  (1, 1, 1, 'ACCEPTED', 'DELIVERED', '2026-08-03 13:20:00', '2026-08-03 13:40:00', '2026-08-03 14:00:00'),
  (2, 2, 3, 'ACCEPTED', 'DELIVERED', '2026-08-10 08:40:00', '2026-08-10 09:00:00', '2026-08-10 09:20:00'),
  (3, 3, 1, 'ACCEPTED', 'DELIVERED', '2026-09-05 20:25:00', '2026-09-05 20:45:00', '2026-09-05 21:05:00'),
  (4, 4, 3, 'ACCEPTED', 'DELIVERED', '2026-08-12 09:10:00', '2026-08-12 09:30:00', '2026-08-12 09:50:00'),
  (5, 5, 6, 'ACCEPTED', 'DELIVERED', '2026-09-14 19:40:00', '2026-09-14 20:00:00', '2026-09-14 20:20:00'),
  (6, 6, 2, 'ACCEPTED', 'DELIVERED', '2026-08-20 21:10:00', '2026-08-20 21:30:00', '2026-08-20 21:50:00'),
  (7, 7, 1, 'ACCEPTED', 'DELIVERED', '2026-07-18 20:10:00', '2026-07-18 20:30:00', '2026-07-18 20:50:00'),
  (8, 8, 2, 'ACCEPTED', 'DELIVERED', '2026-09-22 22:20:00', '2026-09-22 22:40:00', '2026-09-22 23:00:00'),
  (9, 9, 6, 'ACCEPTED', 'DELIVERED', '2026-10-02 13:55:00', '2026-10-02 14:15:00', '2026-10-02 14:35:00'),
  (10, 11, 5, 'ACCEPTED', 'DELIVERED', '2026-08-25 08:25:00', '2026-08-25 08:45:00', '2026-08-25 09:05:00'),
  (11, 12, 2, 'ACCEPTED', 'DELIVERED', '2026-10-08 20:55:00', '2026-10-08 21:15:00', '2026-10-08 21:35:00'),
  (12, 13, 3, 'ACCEPTED', 'DELIVERED', '2026-10-20 13:10:00', '2026-10-20 13:30:00', '2026-10-20 13:50:00'),
  (13, 14, 6, 'ACCEPTED', 'DELIVERED', '2026-09-02 12:30:00', '2026-09-02 12:50:00', '2026-09-02 13:10:00'),
  (14, 16, 1, 'ACCEPTED', 'DELIVERED', '2026-10-25 20:00:00', '2026-10-25 20:20:00', '2026-10-25 20:40:00'),
  (15, 17, 2, 'ACCEPTED', 'PICKED_UP', '2026-10-28 21:40:00', '2026-10-28 22:10:00', NULL),
  (16, 18, 3, 'ACCEPTED', 'DELIVERED', '2026-11-05 13:40:00', '2026-11-05 14:00:00', '2026-11-05 14:20:00'),
  (17, 20, 5, 'ACCEPTED', 'DELIVERED', '2026-11-09 08:55:00', '2026-11-09 09:15:00', '2026-11-09 09:35:00'),
  (18, 21, 1, 'ACCEPTED', 'DELIVERED', '2026-11-10 12:40:00', '2026-11-10 13:00:00', '2026-11-10 13:20:00'),
  (19, 22, 1, 'ACCEPTED', 'DELIVERED', '2026-11-11 13:10:00', '2026-11-11 13:30:00', '2026-11-11 13:50:00'),
  (20, 23, 3, 'ACCEPTED', 'DELIVERED', '2026-11-11 20:10:00', '2026-11-11 20:30:00', '2026-11-11 20:50:00'),
  (21, 24, 3, 'ACCEPTED', 'DELIVERED', '2026-11-12 09:10:00', '2026-11-12 09:30:00', '2026-11-12 09:50:00'),
  (22, 1, 4, 'REJECTED', 'PENDING', '2026-08-03 13:12:00', NULL, NULL);

INSERT INTO review (review_id, order_id, customer_id, restaurant_id, rating, comment, created_at) VALUES
  (1, 1, 1, 1, 5, 'Paneer was fantastic', '2026-08-04 13:10:00'),
  (2, 2, 1, 2, 4, 'Hot and fresh dosa', '2026-08-11 08:30:00'),
  (3, 3, 1, 1, 5, 'Best biryani in town', '2026-09-06 20:15:00'),
  (4, 4, 2, 2, 4, 'Quick delivery', '2026-08-13 09:00:00'),
  (5, 5, 2, 3, 3, 'Noodles were a bit oily', '2026-09-15 19:30:00'),
  (6, 6, 3, 4, 4, 'Burgers were juicy', '2026-08-21 21:00:00'),
  (7, 7, 3, 1, 5, 'Great portions', '2026-07-19 20:00:00'),
  (8, 9, 4, 3, 4, 'Tasty and on time', '2026-10-03 13:45:00'),
  (9, 11, 5, 2, 5, 'Authentic South Indian taste', '2026-08-26 08:15:00'),
  (10, 12, 5, 4, 3, 'Fries arrived cold', '2026-10-09 20:45:00'),
  (11, 14, 6, 3, 2, 'Delivery took too long', '2026-09-03 12:20:00');

INSERT INTO item_review (order_id, item_id, rating, comment) VALUES
  (1, 1, 5, 'Rich and creamy'),
  (3, 5, 5, 'Perfectly spiced'),
  (6, 17, 4, 'Good veg burger'),
  (11, 7, 5, 'Crispy and tasty');

INSERT INTO cart (cart_id, customer_id, restaurant_id) VALUES
  (1, 8, 1),
  (2, 4, 3);

INSERT INTO cart_item (cart_id, item_id, quantity) VALUES
  (1, 1, 1),
  (1, 3, 2),
  (2, 12, 1),
  (2, 15, 1);

SET @bulk_load = NULL;

-- INSERT, UPDATE and DELETE operations (rolled back at the end so the sample data stays unchanged)
START TRANSACTION;

INSERT INTO customer (full_name, email, mobile, password_hash)
VALUES ('Neha Kapoor', 'neha.kapoor@mail.com', '9876500009', '$2b$12$hashed_pw_9');
SET @new_cust = LAST_INSERT_ID();
INSERT INTO customer_address (customer_id, label, address_line, city, pincode, is_default)
VALUES (@new_cust, 'Home', '77 HSR Layout', 'Bengaluru', '560102', 1);
SET @new_addr = LAST_INSERT_ID();

UPDATE customer SET mobile = '9876599999' WHERE customer_id = @new_cust;

UPDATE menu_item SET price = 300.00 WHERE item_id = 1;

UPDATE menu_item SET is_available = 0 WHERE item_id = 20;
UPDATE menu_item SET is_available = 1 WHERE item_id = 11;

UPDATE orders SET status = 'CONFIRMED' WHERE order_id = 19;

UPDATE orders SET status = 'CANCELLED', cancel_reason = 'Delay in preparation', cancelled_at = NOW()
WHERE order_id = 19;

SELECT item_id, price, is_available FROM menu_item WHERE item_id IN (7, 10) FOR UPDATE;
INSERT INTO orders (customer_id, restaurant_id, address_id, order_datetime, status,
                    subtotal, delivery_charge, discount_amount, final_amount, estimated_delivery_time)
VALUES (@new_cust, 2, @new_addr, '2026-11-13 09:00:00', 'PLACED', 170.00, 30.00, 0, 200.00,
        '2026-11-13 09:45:00');
SET @new_order = LAST_INSERT_ID();
INSERT INTO order_status_history (order_id, status, changed_at) VALUES (@new_order, 'PLACED', '2026-11-13 09:00:00');
INSERT INTO order_item (order_id, item_id, quantity, unit_price) VALUES (@new_order, 7, 1, 120.00), (@new_order, 10, 1, 50.00);

DELETE FROM cart_item WHERE cart_id = (SELECT cart_id FROM cart WHERE customer_id = 8);

INSERT INTO food_category (category_name) VALUES ('Combos');
DELETE FROM food_category WHERE category_name = 'Combos';

UPDATE customer
SET is_deleted = 1, full_name = 'Deleted User', email = CONCAT('deleted_', customer_id, '@removed.local'),
    mobile = CONCAT('9', LPAD(customer_id, 9, '0'))
WHERE customer_id = @new_cust;

ROLLBACK;

-- Q1: Display all registered customers.
SELECT customer_id, full_name, email, mobile, created_at
FROM customer
WHERE is_deleted = 0;

-- Q2: Display all active restaurants.
SELECT restaurant_id, name, city, opening_time, closing_time
FROM restaurant
WHERE is_active = 1;

-- Q3: Find all vegetarian food items.
SELECT item_id, item_name, price
FROM menu_item
WHERE is_veg = 1;

-- Q4: Display food items belonging to a particular restaurant.
SELECT m.item_id, m.item_name, m.price, m.is_veg, m.is_available
FROM menu_item m
JOIN restaurant r ON r.restaurant_id = m.restaurant_id
WHERE r.name = 'Spice Garden';

-- Q5: Find food items whose price is greater than Rs. 200.
SELECT item_id, item_name, price
FROM menu_item
WHERE price > 200
ORDER BY price DESC;

-- Q6: Display all orders placed by a particular customer.
SELECT o.order_id, o.order_datetime, o.status, o.final_amount
FROM orders o
JOIN customer c ON c.customer_id = o.customer_id
WHERE c.full_name = 'Aarav Sharma'
ORDER BY o.order_datetime;

-- Q7: Find all orders placed on a particular date.
SELECT order_id, customer_id, restaurant_id, status, final_amount
FROM orders
WHERE DATE(order_datetime) = '2026-10-25';

-- Q8: Display all available delivery partners.
SELECT partner_id, full_name, mobile, vehicle_type
FROM delivery_partner
WHERE availability = 'AVAILABLE';

-- Q9: Display customer details along with their delivery addresses.
SELECT c.customer_id, c.full_name, c.mobile,
       a.label, a.address_line, a.city, a.pincode, a.is_default
FROM customer c
INNER JOIN customer_address a ON a.customer_id = c.customer_id
ORDER BY c.customer_id, a.is_default DESC;

-- Q10: Display restaurant names along with their food menu.
SELECT r.name AS restaurant, m.item_name, c.category_name, m.price
FROM restaurant r
LEFT JOIN menu_item m     ON m.restaurant_id = r.restaurant_id
LEFT JOIN food_category c ON c.category_id   = m.category_id
ORDER BY r.name, c.category_name, m.item_name;

-- Q11: Display complete order details, including customer and restaurant information.
SELECT o.order_id, o.order_datetime, o.status,
       c.full_name AS customer, c.mobile,
       r.name AS restaurant,
       m.item_name, oi.quantity, oi.unit_price, (oi.quantity * oi.unit_price) AS line_total,
       o.subtotal, o.delivery_charge, o.discount_amount, o.final_amount
FROM orders o
JOIN customer c   ON c.customer_id   = o.customer_id
JOIN restaurant r ON r.restaurant_id = o.restaurant_id
JOIN order_item oi ON oi.order_id    = o.order_id
JOIN menu_item m  ON m.item_id       = oi.item_id
ORDER BY o.order_id, m.item_name;

-- Q12: Find the total number of orders placed by each customer.
SELECT c.customer_id, c.full_name, COUNT(o.order_id) AS total_orders
FROM customer c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.full_name
ORDER BY total_orders DESC;

-- Q13: Find the total number of food items available in each restaurant.
SELECT r.restaurant_id, r.name, COUNT(m.item_id) AS available_items
FROM restaurant r
LEFT JOIN menu_item m ON m.restaurant_id = r.restaurant_id AND m.is_available = 1
GROUP BY r.restaurant_id, r.name;

-- Q14: Calculate the total sales generated by each restaurant.
SELECT r.restaurant_id, r.name, COALESCE(SUM(o.final_amount), 0) AS total_sales
FROM restaurant r
LEFT JOIN orders o ON o.restaurant_id = r.restaurant_id AND o.status = 'DELIVERED'
GROUP BY r.restaurant_id, r.name
ORDER BY total_sales DESC;

-- Q15: Find the most frequently ordered food item.
SELECT m.item_id, m.item_name, SUM(oi.quantity) AS total_qty
FROM order_item oi
JOIN orders o     ON o.order_id = oi.order_id AND o.status <> 'CANCELLED'
JOIN menu_item m  ON m.item_id  = oi.item_id
GROUP BY m.item_id, m.item_name
HAVING SUM(oi.quantity) = (
    SELECT MAX(t.qty) FROM (
        SELECT SUM(oi2.quantity) AS qty
        FROM order_item oi2
        JOIN orders o2 ON o2.order_id = oi2.order_id AND o2.status <> 'CANCELLED'
        GROUP BY oi2.item_id) t);

-- Q16: Find customers who have never placed an order.
SELECT c.customer_id, c.full_name
FROM customer c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;

-- Q17: Display delivery partners who have completed more than five deliveries.
SELECT p.partner_id, p.full_name, COUNT(*) AS completed_deliveries
FROM delivery_partner p
JOIN delivery d ON d.partner_id = p.partner_id AND d.delivery_status = 'DELIVERED'
GROUP BY p.partner_id, p.full_name
HAVING COUNT(*) > 5;

-- Q18: Find the average rating of each restaurant.
SELECT r.restaurant_id, r.name, COUNT(rv.review_id) AS reviews, ROUND(AVG(rv.rating), 2) AS avg_rating
FROM restaurant r
LEFT JOIN review rv ON rv.restaurant_id = r.restaurant_id
GROUP BY r.restaurant_id, r.name
ORDER BY avg_rating DESC;

-- Q19: Find the customer who has spent the highest amount on food orders.
SELECT c.customer_id, c.full_name, SUM(o.final_amount) AS total_spent
FROM customer c
JOIN orders o ON o.customer_id = c.customer_id AND o.status = 'DELIVERED'
GROUP BY c.customer_id, c.full_name
HAVING SUM(o.final_amount) = (
    SELECT MAX(s.total) FROM (
        SELECT SUM(final_amount) AS total FROM orders
        WHERE status = 'DELIVERED' GROUP BY customer_id) s);

-- Q20: Find the restaurant that generated the highest revenue.
SELECT r.restaurant_id, r.name, SUM(o.final_amount) AS revenue
FROM restaurant r
JOIN orders o ON o.restaurant_id = r.restaurant_id AND o.status = 'DELIVERED'
GROUP BY r.restaurant_id, r.name
ORDER BY revenue DESC
LIMIT 1;

-- Q21: Find the second most expensive food item.
SELECT item_id, item_name, price
FROM menu_item
WHERE price = (SELECT MAX(price) FROM menu_item
               WHERE price < (SELECT MAX(price) FROM menu_item));

-- Q22: Find restaurants whose average ratings are greater than the overall average rating.
SELECT r.restaurant_id, r.name, ROUND(AVG(rv.rating), 2) AS avg_rating
FROM restaurant r
JOIN review rv ON rv.restaurant_id = r.restaurant_id
GROUP BY r.restaurant_id, r.name
HAVING AVG(rv.rating) > (SELECT AVG(rating) FROM review);

-- Q23: Find customers who have placed more orders than the average number of orders per customer.
SELECT c.customer_id, c.full_name, COUNT(o.order_id) AS order_count
FROM customer c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.full_name
HAVING COUNT(o.order_id) > (
    SELECT AVG(cnt) FROM (SELECT COUNT(*) AS cnt FROM orders GROUP BY customer_id) x);

-- Q24: Find food items that have never been ordered.
SELECT m.item_id, m.item_name, r.name AS restaurant
FROM menu_item m
JOIN restaurant r ON r.restaurant_id = m.restaurant_id
WHERE NOT EXISTS (SELECT 1 FROM order_item oi WHERE oi.item_id = m.item_id);

-- Q25: Find the top three best-selling food items.
SELECT m.item_id, m.item_name, SUM(oi.quantity) AS qty_sold
FROM order_item oi
JOIN orders o    ON o.order_id = oi.order_id AND o.status = 'DELIVERED'
JOIN menu_item m ON m.item_id  = oi.item_id
GROUP BY m.item_id, m.item_name
ORDER BY qty_sold DESC, m.item_name
LIMIT 3;

-- Q26: Identify customers who have used promotional coupons.
SELECT DISTINCT c.customer_id, c.full_name, cp.code, cr.discount_given, cr.redeemed_at
FROM coupon_redemption cr
JOIN customer c ON c.customer_id = cr.customer_id
JOIN coupon cp  ON cp.coupon_id  = cr.coupon_id
ORDER BY c.customer_id;

-- Q27: Find restaurants that have not received any orders.
SELECT r.restaurant_id, r.name
FROM restaurant r
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.restaurant_id = r.restaurant_id);

-- Q28: Generate monthly restaurant revenue reports.
SELECT r.name AS restaurant,
       DATE_FORMAT(o.order_datetime, '%Y-%m') AS month,
       COUNT(*) AS delivered_orders,
       SUM(o.final_amount) AS revenue
FROM orders o
JOIN restaurant r ON r.restaurant_id = o.restaurant_id
WHERE o.status = 'DELIVERED'
GROUP BY r.restaurant_id, r.name, DATE_FORMAT(o.order_datetime, '%Y-%m')
ORDER BY month, revenue DESC;

-- Q29: Find delivery partners with the highest number of completed deliveries.
SELECT p.partner_id, p.full_name, COUNT(*) AS completed_deliveries
FROM delivery_partner p
JOIN delivery d ON d.partner_id = p.partner_id AND d.delivery_status = 'DELIVERED'
GROUP BY p.partner_id, p.full_name
HAVING COUNT(*) = (
    SELECT MAX(x.cnt) FROM (
        SELECT COUNT(*) AS cnt FROM delivery WHERE delivery_status = 'DELIVERED' GROUP BY partner_id) x);

-- Q30: Identify customers who have placed orders but have never submitted a review.
SELECT c.customer_id, c.full_name
FROM customer c
WHERE EXISTS     (SELECT 1 FROM orders o  WHERE o.customer_id = c.customer_id)
  AND NOT EXISTS (SELECT 1 FROM review rv WHERE rv.customer_id = c.customer_id);

-- RIGHT JOIN: Display every restaurant with its orders, including restaurants with no orders.
SELECT r.name, o.order_id, o.final_amount
FROM orders o
RIGHT JOIN restaurant r ON r.restaurant_id = o.restaurant_id
ORDER BY r.name;

-- Views: Display restaurant ratings, monthly revenue and delivered order summary using the views.
SELECT * FROM v_restaurant_rating;
SELECT * FROM v_restaurant_monthly_revenue ORDER BY month, revenue DESC;
SELECT * FROM v_order_summary WHERE status = 'DELIVERED';

-- Order tracking: Display the status history and delivery partner of an order.
SELECT h.status, h.changed_at, p.full_name AS delivery_partner, o.estimated_delivery_time
FROM orders o
JOIN order_status_history h ON h.order_id = o.order_id
LEFT JOIN delivery d  ON d.order_id = o.order_id AND d.assignment_status = 'ACCEPTED'
LEFT JOIN delivery_partner p ON p.partner_id = d.partner_id
WHERE o.order_id = 3
ORDER BY h.changed_at;

-- Index: Check that the index is used when searching a customer's orders.
EXPLAIN SELECT * FROM orders WHERE customer_id = 1 AND order_datetime >= '2026-08-01';
