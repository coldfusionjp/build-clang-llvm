FROM coldfusionjp/amazon-linux-clang:2018.03.0.20190514-clang-8.0.1-rc3

WORKDIR /root
COPY test.cpp .
RUN clang++ -flto -o test test.cpp
CMD [ "/root/test" ]
