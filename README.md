# Roda Json Api
`rake db:migrate`
`rake db:seed` # initial population with data for performance testing

`rackup` # start app

# Техническое задание

Требуется создать JSON API сервис на Ruby. В качестве веб-фреймворка, можете использовать sinatra, hanami, roda или что-нибудь другое, но не Ruby on Rails. Доспут к БД можете осуществлять с помощью ORM (active_record, sequel, rom), можете и без ORM, как посчитаете нужным.

## 1. Сущности:
  1. **Юзер**. Имеет только логин.
  2. **Пост**. Принадлежит **юзеру**. Имеет заголовок, содержание, айпи автора (сохраняется отдельно для каждого поста).
  3. **Оценка**. Принадлежит **посту**. Принимает _значение от 1 до 5_.

## 2. Экшены:
  1. Создать пост. Принимает заголовок и содержание поста (не могут быть пустыми), а также логин и айпи автора. Если автора с таким логином еще нет, необходимо его создать. Возвращает либо атрибуты поста со статусом 200, либо ошибки валидации со статусом 422.
  2. Поставить оценку посту. Принимает айди поста и значение, возвращает новый средний рейтинг поста. Важно: экшен должен корректно отрабатывать при любом количестве конкурентных запросов на оценку одного и того же поста.
  3. Получить топ N постов по среднему рейтингу. Просто массив объектов с заголовками и содержанием.
  4. Получить список айпи, с которых постило несколько разных авторов. Массив объектов с полями: айпи и массив логинов авторов.

## 3. База данных
Базу данных используем **PostgreSQL**. 
Для девелопмента написать скрипт в **db/seeds.rb**, который генерирует тестовые данные. Часть постов должна получить оценки. Скрипт должен использовать созданный JSON API сервер (можно посылать запросы курлом или еще чем-нибудь).

Постов в базе должно быть хотя бы **200к**, авторов лучше сделать в районе **100 штук**, айпишников использовать штук **50** разных.

Экшены должны на стандартном железе работать достаточно быстро как для указанного объема данных (**быстрее 100 мс**, если будет работать медленне, то ничего страшного, все равно присылайте решение), так и для намного большего, то есть нужен хороший запас в плане оптимизации запросов. Для этого можно использовать денормализацию данных и любые другие средства БД. Можно использовать любые нужные гемы, обязательно наличие спеков, хорошо покрывающих разные кейсы. Архитектуру сервиса организуйте на "свой вкус". Желательно не использовать генераторов и вообще обойтись без лишних мусорных файлов в репозитории.

# Принятые решения

### Данные
  1. **Users**: id, login
  2. **Posts**: id, title, content, ip, user_id, ratings_sum, ratings_count
  3. **Ratings**: id, rating, created_at, post_id
  
### Хранение и вычисление рейтинга поста
Для поста будем хранить сумму и количество его рейтингов (оценок).
Это позволит иметь данные для быстрого расчета рейтинга при в экшене оценки поста. Достаточно будет сохранить новый рейтинг, рассчитать новые сумму оценок ratings_summa += rating и количество оценок ratings_count += 1.
И сразу можно вернуть новое значение среденего рейтинга: ratings_summa / ratings_count.

В случае сбоев рейтинг поста можно всегда пересмчитать по значениям из таблицы Ratins

### Roda + Sequel
Для реализации выбран фреймворк Roda (1. самый призводительный после rake, 2. интересно было с ним поработать, т.к. ранее много о нем слышал, но не тестировал)
Для работы с БД выбрана библиотека Sequel того же автора. Она немного облегчит работу с моделями и позвоит сократить код.


# Подготовка и запуск
## База данных
Параметры доступа к БД хранятся в **.env**-файле:
```
$ cat .env
PGDATABASE=api
PGUSER=api
PGPASSWORD=api_pwd
```
```
$ sudo -u postgres psql
# create user api with password 'api_pwd';
# create database api owner api;
```



Для работы нужно создать пользователя БД, задать ему пароль, создать БД.
Затем запустить миграции `rake db:migrate` и заселить первоначальные данные `rake db:seed`.
С помощью генератора данных `Faker` будет сделано:
  - 100 пользователей (авторов);
  - 50 ip-адроесов IP4;
  - 200к постов, примерно 10% будут иметь оценки;
  
Далее можно запустить сервис `rackup` и проверить экшены:
  1. Создать пост.
```
$ curl -X POST -H "Content-Type: application/json" -d '{"title":"post title 2", "content":"post content 2", "user_login":"julia", "user_ip":"192.168.1.102"}' http://localhost:9292/api/v1/posts/create

{ data: { post: {
      id: 117,
      title: post title 2,
      content: post content 2,
      rating: 0,
      ip: 192.168.1.102,
      user: { id: 30, login: julia }
    } } }
```

  2. Поставить оценку посту.
````
$ curl -H "Content-Type: application/json" -X PUT -d '{"rate":"4"}' http://localhost:9292/api/v1/posts/108

{ data: { post_id: 108, rating: 4.16667 } }
````

  3. Получить топ N постов по среднему рейтингу.
```
$ curl -H "Content-Type: application/json" "http://localhost:9292/api/v1/posts?limit=10&rating=2"

{ data: { posts: [ { post_id: 84, rating: 2.66700, title: nihil sed accusantium explicabo enim, content: Commodi veritatis officia. Recusandae debitis et. Ut neque vel. },
{ post_id: 26, rating: 2.00000, title: quia ea dolorem voluptas provident saepe, content: Veritatis non est. At nesciunt non. Occaecati veniam laudantium. Quo ut accusamus. },
{ post_id: 62, rating: 2.00000, title: eum culpa rerum, content: Voluptas fuga esse. Sed dolor earum. },
{ post_id: 46, rating: 2.66700, title: ut illo aliquam nemo qui nihil et, content: Odit magni id. Aperiam ea magni. Ut commodi vel. },
{ post_id: 101, rating: 2.00000, title: post title, content: post_content },
{ post_id: 104, rating: 2.50000, title: post title, content: post_content } ] } }
```

  4. Получить список ip, с которых постило несколько разных авторов.
```$ curl -H "Content-Type: application/json" "http://localhost:9292/api/v1/posts/ip_authors"

{ data: { ips: [ { ip: 64.176.52.175, authors: ["roderick", "stuart_littel"] },
{ ip: 156.187.214.230, authors: ["leslie", "emerson"] },
{ ip: 163.153.121.170, authors: ["ron_walker", "petronila.kautzer"] },
{ ip: 209.6.224.58, authors: ["gerardo", "stuart_littel"] },
{ ip: 31.10.180.29, authors: ["julian_tillman", "roxanna"] },
{ ip: 138.250.200.174, authors: ["mozella.gutkowski", "roscoe"] },
{ ip: 224.199.0.0, authors: ["gerard.larson", "celsa"] },
{ ip: 99.33.234.163, authors: ["salvatore_lindgren", "leslie"] } ] } }
```

# Результат
Общие затраты времени порядка 16 часов. Много времени ушло на изучение Roda и Sequel.
Тестирование на Ubuntu 20.04.1 LTS + AMD® Ryzen 5 3500u + RAM 8GB.
Для оценки призводительности использовал опцию `-w "%{time_total}\n"` в параметрах curl:

  1. Создать пост - 0,008370
  2. Поставить оценку посту - 0,009061
  3. Получить топ N постов по среднему рейтингу - 0,082882
  4. Получить список ip с разными авторами - 0,126522

# Что не сделано

1. Тестирование. Только подбираюсь к нему.
2. Сервис возвращает либо корректные данные и статус 200, либо ничего и статус 404. Нужно выделить render для success и error вариантов.
3. Не стал выделять модели в отдельные файлы, не стал пока переносить логику в модели

Планирую продолжить дорабатывать закончить этот проект ориентировочно 16.10.2020.



create index on posts USING gist (ip inet_ops);


https://fooobar.com/questions/395416/writing-unit-tests-in-ruby-for-a-rest-api
https://ruby-doc.org/stdlib-2.1.2/libdoc/test/unit/rdoc/Test/Unit.html
http://sinatrarb.com/testing.html
