# database control
DROP DATABASE IF EXISTS ecommerce;
CREATE DATABASE ecommerce;
USE ecommerce;
--------------------------------------------------------------------------
# add table my importing wizard
--------------------------------------------------------------------------
ALTER TABLE company ADD PRIMARY KEY (store_id);
ALTER TABLE product ADD PRIMARY KEY (product_id);
ALTER TABLE `user` ADD PRIMARY KEY (user_id);

ALTER TABLE company CHANGE store_id store_id INT AUTO_INCREMENT;
ALTER TABLE product CHANGE product_id product_id INT AUTO_INCREMENT;
ALTER TABLE `user` CHANGE user_id user_id INT AUTO_INCREMENT;

ALTER TABLE sales_transaction
ADD FOREIGN KEY (store_id) REFERENCES company(store_id),
ADD FOREIGN KEY (product_id) REFERENCES product(product_id),
ADD FOREIGN KEY (user_id) REFERENCES `user`(user_id);
--------------------------------------------------------------------------
# format date
CREATE TABLE sales_transaction_ AS SELECT *, STR_TO_DATE(`datetime`, '%m/%d/%Y') AS `date` FROM sales_transaction;
DROP TABLE IF EXISTS sales_transaction;
RENAME TABLE sales_transaction_ TO sales_transaction;
ALTER TABLE sales_transaction DROP COLUMN `datetime`;
SELECT * FROM sales_transaction;
--------------------------------------------------------------------------
# create master table
DROP TABLE IF EXISTS `master`;
CREATE TABLE `master` AS SELECT a.*, b.price, b.price*a.amount AS sales, c.store_name, c.region as store_region, c.email as store_email,
	d.username, d.user_email, d.country as user_country, d.gender as user_gender FROM sales_transaction a
LEFT JOIN product b ON a.product_id=b.product_id
LEFT JOIN company c ON a.store_id=c.store_id
LEFT JOIN `user` d ON a.`user_id`=d.`user_id`;

# truncate the decimal irregularities
ALTER TABLE `master`
MODIFY COLUMN sales DECIMAL(10,1);
--------------------------------------------------------------------------
# add time dimension using procedure
DROP TABLE IF EXISTS time_dimension;
CREATE TABLE time_dimension (
        db_date                 DATE PRIMARY KEY,
        id                      INTEGER NOT NULL,  -- year*10000+month*100+day
        year                    INTEGER NOT NULL,
        month                   INTEGER NOT NULL, -- 1 to 12
        day                     INTEGER NOT NULL, -- 1 to 31
        quarter                 INTEGER NOT NULL, -- 1 to 4
        week                    INTEGER NOT NULL, -- 1 to 52/53
        day_name                VARCHAR(9) NOT NULL, -- 'Monday', 'Tuesday'...
        month_name              VARCHAR(9) NOT NULL, -- 'January', 'February'...
        UNIQUE td_ymd_idx (year,month,day),
        UNIQUE td_dbdate_idx (db_date)
);

DROP PROCEDURE IF EXISTS fill_date_dimension;
DELIMITER //
CREATE PROCEDURE fill_date_dimension(IN startdate DATE,IN stopdate DATE)
BEGIN
    DECLARE currentdate DATE;
    SET currentdate = startdate;
    WHILE currentdate <= stopdate DO
        INSERT INTO time_dimension VALUES (
            currentdate,
            YEAR(currentdate)*10000+MONTH(currentdate)*100 + DAY(currentdate),
            YEAR(currentdate),
            MONTH(currentdate),
            DAY(currentdate),
            QUARTER(currentdate),
            WEEKOFYEAR(currentdate),
            DATE_FORMAT(currentdate,'%W'),
            DATE_FORMAT(currentdate,'%M')
            );
        SET currentdate = ADDDATE(currentdate,INTERVAL 1 DAY);
    END WHILE;
END
//
DELIMITER ;

TRUNCATE TABLE time_dimension;
CALL fill_date_dimension('2022-01-01','2022-12-31');
OPTIMIZE TABLE time_dimension;
SELECT * FROM time_dimension;
--------------------------------------------------------------------------
ALTER TABLE sales_transaction
ADD FOREIGN KEY (`date`) REFERENCES time_dimension(`db_date`);
--------------------------------------------------------------------------
# product summary
DROP TABLE IF EXISTS product_summary;
CREATE TABLE product_summary (max_price DOUBLE, min_price DOUBLE, avg_price DECIMAL(10,1));
INSERT INTO product_summary (SELECT MAX(price), MIN(price), AVG(price) FROM product);
SELECT * FROM product_summary;
--------------------------------------------------------------------------
# trigger for inserting row
DROP TRIGGER IF EXISTS add_product;
delimiter //
CREATE TRIGGER add_product AFTER INSERT
ON product
FOR EACH ROW
UPDATE product_summary 
	SET max_price = (SELECT MAX(price) FROM product),
		min_price = (SELECT MIN(price) FROM product),
		avg_price = (SELECT AVG(price) FROM product);//
delimiter ;

INSERT INTO product (product_name, price)
VALUE ("Watermelon", 29);
SELECT * FROM product;
--------------------------------------------------------------------------
# data analysis
SELECT username, SUM(sales) FROM `master` GROUP BY username;
