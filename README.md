# LLP_base2

### Лабораторная работа №2 по низкоуровневому программированию

Вариант - MongoShell

## Сборка и запуск приложения
`sh build.sh`

Запросы задаются в файле `query.mso`

## Примеры запросов
`storage.receive({name:"alex", age: 20, subName: "Vokazrev"})`

`storage.update({name:"alex", age: 20, subName: "Vokazrev"}, $set:{name: "aleks", age: 21})`

