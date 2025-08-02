## maven使用记录
1. maven创建的多模块工程时

  ``` xml
  <parent>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-parent</artifactId>
      <version>3.5.3</version>
      <relativePath/> <!-- lookup parent from repository -->
  </parent>
  只需要在父工程加入<relativePath/>，子模块声明的父工程不要加；不然子工程将因为找不到父工程的pom.xml报错
  <relativePath/> 空标签表示从远程仓库查询父工程的pom.xml文件，子工程默认从本地查询父工程的pom.xml(../pom.xml)
  
  ```

  

```xml
#!/bin/bash
<!--指定配置文件启动项目:-->
mvn spring-boot:run "-Dspring-boot.run.arguments=--spring.config.name=application-order --spring.profiles.active=order"
<!--在使用mvn命令启动和编译项目时,最好在后面参数加双引号以免编辑器错误解析参数-->
mvn clean install -DskipTests

<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.gzulmc</groupId>
    <artifactId>api_gateway</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <name>api_gateway</name>
    <description>api_gateway</description>

    <properties>
        <java.version>17</java.version>
        <maven.compiler.source>17</maven.compiler.source>
        <maven.compiler.target>17</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
        <spring-cloud.version>2025.0.0</spring-cloud.version>
        <spring-boot.version>3.5.3</spring-boot.version>
    </properties>
    <dependencies>
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-gateway-server-webflux</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-loadbalancer</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
        </dependency>
<!--        <dependency>
            <groupId>com.netflix.ribbon</groupId>
            <artifactId>ribbon-loadbalancer</artifactId>
            <version>2.3.0</version>
        </dependency>-->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>org.springframework.cloud</groupId>
                <artifactId>spring-cloud-dependencies</artifactId>
                <version>${spring-cloud.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
            <dependency>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-dependencies</artifactId>
                <version>${spring-boot.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
        </dependencies>
    </dependencyManagement>

    <build>
        <pluginManagement>
            <plugins>
                <plugin>
                    <groupId>org.springframework.boot</groupId>
                    <artifactId>spring-boot-maven-plugin</artifactId>
                    <version>${spring-boot.version}</version>
                    <executions>
                        <execution>
                            <goals>
                                <goal>repackage</goal>
                            </goals>
                        </execution>
                    </executions>
                </plugin>
                <!--<plugin>
                    <groupId>com.spotify</groupId>
                    <artifactId>docker-maven-plugin</artifactId>
                    <version>${docker.plugin.version}</version>
                    <configuration>
                        <imageName>${registry.url}/${project.name}:0.0.1</imageName>
                        <dockerHost>${docker.url}</dockerHost>
                        <dockerDirectory>${project.basedir}</dockerDirectory>
                        <resources>
                            <resource>
                                <targetPath>/</targetPath>
                                <directory>${project.build.directory}</directory>
                                <include>${project.build.finalName}.jar</include>
                            </resource>
                        </resources>
                        <serverId>docker-hub</serverId>
                        <registryUrl>https://index.docker.io/v1/</registryUrl>
                    </configuration>
                </plugin>-->
            </plugins>
        </pluginManagement>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.11.0</version> <!-- 确保版本支持 Java 17 -->
                <configuration>
                    <source>17</source>
                    <target>17</target>
                    <release>17</release> <!-- 可选，但建议添加 -->
                </configuration>
            </plugin>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>

    <repositories>
        <!--阿里云私服-->
        <repository>
            <id>aliyun</id>
            <name>aliyun</name>
            <url>https://maven.aliyun.com/nexus/content/groups/public</url>
        </repository>
        <repository>
            <id>central</id>
            <name>Central Repository</name>
            <url>https://repo.maven.apache.org/maven2</url>
            <releases>
                <enabled>true</enabled>
            </releases>
            <snapshots>
                <enabled>true</enabled>
                <updatePolicy>always</updatePolicy>
            </snapshots>
        </repository>
    </repositories>
</project>


```