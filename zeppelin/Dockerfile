FROM openjdk:8-jdk

ENV ZEPPELIN="http://www-eu.apache.org/dist/zeppelin/zeppelin-0.7.0/zeppelin-0.7.0-bin-all.tgz"
WORKDIR /tmp

RUN mkdir -p /opt/zeppelin && curl ${ZEPPELIN} | tar xzf - --strip-components=1 -C /opt/zeppelin 

RUN echo openshift-user:x:1000050000:0:root:::/bin/false >> /etc/passwd
RUN chown -R root.root /opt/zeppelin
RUN chmod g+rwx /opt/zeppelin 
RUN chmod -R g+rw /opt/zeppelin
EXPOSE 4040 8080 8081

WORKDIR /
ADD boot.sh /

ENTRYPOINT ["/boot.sh"]
