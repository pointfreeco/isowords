CREATE TABLE words (word varchar(256) NOT NULL UNIQUE);
.separator ,
.import /dev/stdin words
