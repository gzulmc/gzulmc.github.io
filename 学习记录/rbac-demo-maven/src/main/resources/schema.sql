CREATE TABLE users (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(100) NOT NULL,
    enabled BOOLEAN DEFAULT TRUE,
    nickname VARCHAR(50)
);

CREATE TABLE roles (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    role_name VARCHAR(50) NOT NULL UNIQUE,
    description VARCHAR(100)
);

CREATE TABLE permissions (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    permission_name VARCHAR(100) NOT NULL,
    url VARCHAR(200) NOT NULL,
    method VARCHAR(10) DEFAULT 'GET',
    description VARCHAR(100)
);

CREATE TABLE user_roles (
    user_id BIGINT NOT NULL,
    role_id BIGINT NOT NULL,
    PRIMARY KEY (user_id, role_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
);

CREATE TABLE role_permissions (
    role_id BIGINT NOT NULL,
    permission_id BIGINT NOT NULL,
    PRIMARY KEY (role_id, permission_id),
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
    FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE
);

INSERT INTO users (id, username, password, enabled, nickname)
VALUES 
(1, 'admin', '{bcrypt}$2a$10$qMdcdFtxoa7DQ.vPWTbkp.HrxHNmBDaXrWxWOkfe28/9PKCOr5JoQa', true, '系统管理员'),
(2, 'user',  '{bcrypt}$2a$10$qMdcdFtxoa7DQ.vPWTbkp.HrxHNmBDaXrWxWOkfe28/9PKCOr5JoQa', true, '普通用户');

INSERT INTO roles (id, role_name, description)
VALUES 
(1, 'ROLE_ADMIN', '管理员角色'),
(2, 'ROLE_USER', '普通用户角色');

INSERT INTO permissions (id, permission_name, url, method, description)
VALUES 
(1, '系统管理权限', '/admin/**', 'GET', '访问后台管理页面'),
(2, '用户页面权限', '/user/**', 'GET', '访问用户页面'),
(3, '首页权限', '/', 'GET', '访问首页');

INSERT INTO user_roles (user_id, role_id)
VALUES 
(1, 1),
(2, 2);

INSERT INTO role_permissions (role_id, permission_id)
VALUES 
(1, 1),
(1, 2),
(1, 3),
(2, 2),
(2, 3);