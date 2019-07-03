## dependence

+ ruby 2.x
+ bundler

## usage

下記のような環境を想定

```
localhost -> ec2(ssh) -> RDS
```

### 事前

実行コマンドファイルに実行権限を付与しください
.envを作成してください
config/database.ymlを作成してください

```
cp .env.example .env
cp config/database.yml.template config/database.yml
```

下記コマンドでライブラリをインストールしてください
```
bundle install --path vendor/bundle
```

### exec

```
./copy.rb -d ダッシュボードslug
```

## extra

+ slugをカンマ区切りで渡すと複数コピーできます

```
./copy.rb -d 7f94-1,7f94-2
```

+ --no-queryを渡すとsqlはcloneしないでquery_idが同一のdashboardがコピーされます
