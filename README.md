# Roulette deployment

This repository contains a docker-compose network build on top of the [roulete.core](https://github.com/GoosvandenBekerom/roulette.core) project.

To run this project locally run the following commands:
- `$ git submodule update --init` (this is only needed the first time to clone the submodules)
- `$ ./run.sh`

## Exposed services
| Service           | Ports        | Additional information
| --------          | --------     | -------
| MySQL             | 3306         | user: root, password: password
| RabbitMQ          | 5672, 15672  | user: guest, password: guest
| Dealer            | 8080         | [roulete.dealer](https://github.com/GoosvandenBekerom/roulette.dealer)
| Monitor           | 8081         | [roulete.monitor](https://github.com/GoosvandenBekerom/roulette.monitor)
| Prometheus        | 9090         | Stats & information about services (JVM and RabbitMQ)
| Grafana           | 3000         | Visual dashboards for Prometheus data

## Architecture (dutch)
In onderstaand diagram breng ik de globale architectuur in kaart.
![Architecture diagram](https://cdn.discordapp.com/attachments/380439326950948874/451380237889044480/Roulette-Architecture.png)

#### Onderbouwing
| Keuze    | Waarom?
| -------- | --------     
| MySQL | Eigenlijk heb ik alleen een simpele datastore nodig waarin de error logs opgeslagen kunnen worden. Ik heb hiervoor gekeken naar Redis, en ik denk ook dat dit een optimalere oplossing zou zijn voor de toepassing. Echter heb ik geen ervaring met Redis en wel met MySQL, en omdat dit niet het onderdeel is waar ik tijd in wil stoppen voor dit project gebruik ik MySQL.
| RabbitMQ | Ik heb gekeken naar JMS (implementaties), ActiveMQ, RabbitMQ en Kafka. Omdat ik voornamelijk gebruik maak van Spring Boot voor de applicaties in dit project, ben ik kort gaan kijken naar de respectievelijke implementaties van deze oplossingen. Ik heb hiervan kleine proof-of-concepts gemaakt waarin een simpel bericht van A naar B gaat via een Queue/Topic. Hieruit bleek al snel dat RabbitMQ en Kafka veruit de beste ondersteuning bieden qua gebruiksvriendelijkheid en simpliciteit, voor beide is erg goede ondersteuning in Spring Boot. Mijn keuze voor RabbitMQ heeft de volgende redenen: 1. Kafka bied momenteel enkel een Java client, in mijn architectuur geef ik al aan dat ik graag open wil staan voor clients (spelers) in verschillende talen. 2. RabbitMQ is enkel een messaging queue, en dit is wat ik zoek. 3. Kafka bied veel mooie oplossingen voor persistentie van berichten en de mogelijkheid op te schalen naar absurd grote clusters. Echter is dit voor mijn applicatie een beetje overkill. 4. Binnen onze proftaak maken we ook gebruik van RabbitMQ, het leek mij waardevol om via deze weg meer te leren over deze software. Het artikel van Pivotal (Pieter Humphrey, 2017) geeft een mooi overzicht van de verschillende overwegingen die je moet maken voor de keuze tussen Kafka en RabbitMQ, dit heeft mij geholpen om tot de 4 bovenstaande redenen te komen.
| Google Protocol buffers | In eerste instantie had ik 2 reden voor protobuf, protobuf is namelijk een formaat waarbij elke Byte telt, het is dus super snel en het gebruikt alleen de bandbreedte die het echt nodig heeft. Dat is de belangrijkste reden, mijn andere reden was omdat je een transformatie moet doen om proto berichten te creeëren, en dit een vereiste is voor DPI6. Later bleek dat dit niet het type transformatie is dat daarmee wordt bedoeld. Het artikel "5 Reasons to Use Protocol Buffers Instead of JSON For Your Next Service" geeft een mooi overzicht van de voor en nadelen van protobuf.
| Transformatie | Omdat bovenstaande transformatie dus niet genoeg was om dit onderdeel af te ronden ben ik het monitor project gaan schrijven. Deze luistert naar de error queue en vangt hiervan alle Protobuf error message's op, transformeert deze naar JSON en bied ze aan via een paginated REST api.
| Prometheus / Grafana | Als je googled naar monitoring oplossingen voor Spring Boot kun je niet om Prometheus en Grafana heen, ze komen overal meteen naar boven. Ik heb hier dus niet lang over nagedacht en ben ze gewoon gaan gebruiken. Het mooie aan het prometheus dataformaat is dat er voor zo'n beetje alles exporters zijn geschreven. Ik heb een Prometheus docker container gebouwd die de data van al deze exporters bundelt. Vervolgens leest Grafana deze gebundelde data uit en geeft een visuele representatie van deze data weer.
| Fanout Exchange | De reden dat ik een fanout exchange toe heb gepast en niet alleen de topic is zodat het mogelijk is voor een client op een game te bekijken zonder mee te spelen. alle informatie die openbaar beschikbaar mag zijn (denk aan nieuwe tafel, nieuw resultaat e.d.) wordt daarom via deze exchange verspreid.
| Players via Topic ipv Headers | In mijn initiele architectuur ontwerp maakte ik gebruik van een headers exchange om zo spelers individueel informatie te kunnen sturen. Buiten de complicaties die dit met zich mee bracht heb ik in het artikel "Performance Tuning Our RabbitMQ Routing Strategy" gelezen over hoe headers exchanges vele malen minder performant zijn dan topic exchanges.

##### Bronvermelding
- Humphrey, P. (2017, 26 april). Understanding When to use RabbitMQ or Apache Kafka. Geraadpleegd op 20 mei 2018, van https://content.pivotal.io/blog/understanding-when-to-use-rabbitmq-or-apache-kafka
- Bernstein, M. (2014, 5 juni). 5 Reasons to Use Protocol Buffers Instead of JSON For Your Next Service. Geraadpleegd op 25 mei 2018, van http://techblog.betgenius.com/performance-tuning-our-rabbitmq-routing-strategy/https://codeclimate.com/blog/choose-protocol-buffers/
- Performance Tuning Our RabbitMQ Routing Strategy. (2014, 21 oktober). Geraadpleegd op 25 mei 2018, van http://techblog.betgenius.com/performance-tuning-our-rabbitmq-routing-strategy/

#### Berichten
Om bovenstaande architectuur werkelijkheid te maken heb ik de volgende berichten gebruikt:

| Bericht | Data 
| ------- | ------ 
| nieuwe speler  | naam 
| inkopen        | speler, hoeveelheid 
| inzetten       | speler, hoeveelheid, type inzet, (optioneel: nummers) 
| inzet status   | open/gesloten 
| resultaat      | nummer, kleur 
| speler / chips | speler, hoeveelheid 
| foutmelding    | bericht, context, speler 

Hieronder is te zien hoe deze berichten er uitzien in de Google Protocol Buffers definitie.

```
message NewPlayerRequest {
  string name = 1;
}

message NewPlayerResponse {
  int64 id = 1;
}

message BuyInRequest {
  int64 player_id = 1;
  int32 amount = 2;
}

message BetRequest {
  int64 player_id = 1;
  int32 amount = 3;
  BetType type = 4;
  repeated int32 number = 5;
  enum BetType {
    ODD = 0;
    EVEN = 1;
    RED = 3;
    BLACK = 4;
    FIRST_HALf = 5;
    SECOND_HALF = 6;
    FIRST_DOZEN = 7;
    SECOND_DOZEN = 8;
    THIRD_DOZEN = 9;
    FIRST_COLUMN = 10;
    SECOND_COLUMN = 11;
    THIRD_COLUMN = 12;
    NUMBER = 13;
    TWO_NUMBER = 14;
    THREE_NUMBER = 15;
    FOUR_NUMBER = 16;
    FIVE_NUMBER = 17;
    SIX_NUMBER = 18;
  }
}

message UpdateBettingStatus {
  bool status = 1;
}

message NewResult {
  int32 number = 2;
  string color = 3;
}

message PlayerAmountUpdate {
  int64 player_id = 1;
  int32 amount = 2;
}

message Error {
  string message = 1;
  string context = 2;
  string username = 3;
}
```