{ pkgs }:
pkgs.writeShellApplication {
  name = "rj-notifier";
  runtimeInputs = with pkgs; [ curl jq libnotify coreutils ];
  text = ''
    set -euxo pipefail

    ##############################################
    # make sure this matches the RJ timetable    #
    # for the given day                          #
    ##############################################
    departure_time="2025-10-31T18:00:00.000+02:00"
    ##############################################

    liberecId=17904003
    pragueId=10202003

    ##############################################
    from=$pragueId
    to=$liberecId
    ##############################################

    departure_date=$(echo $departure_time | cut -d'T' -f1)
    while true; do
      echo -n "checking at ";
      date;
      n_seats_available="$(curl \
        --noproxy '*' \
        -s "https://brn-ybus-pubapi.sa.cz/restapi/routes/search/simple?tariffs=REGULAR&toLocationType=CITY&toLocationId=$to&fromLocationType=CITY&fromLocationId=$from&departureDate=$departure_date&fromLocationName=&toLocationName=" \
        -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:134.0) Gecko/20100101 Firefox/134.0' \
        -H 'Accept: application/1.2.0+json' \
        -H 'Accept-Language: en-GB,en-US;q=0.7,en;q=0.3' \
        -H 'Accept-Encoding: gzip, deflate, br, zstd' \
        -H 'X-Lang: cs' \
        -H 'X-Currency: CZK' \
        -H 'Cache-Control: no-cache' \
        -H 'X-Application-Origin: WEB' \
        -H 'Authorization: Bearer XXX' \
        -H 'Origin: https://regiojet.cz' \
        -H 'DNT: 1' \
        -H 'Connection: keep-alive' \
        -H 'Referer: https://regiojet.cz/' \
        -H 'Sec-Fetch-Dest: empty' \
        -H 'Sec-Fetch-Mode: cors' \
        -H 'Sec-Fetch-Site: cross-site' \
        -H 'Pragma: no-cache' \
        -H 'TE: trailers' \
        | jq "[ .routes | .[] | {seats: .freeSeatsCount, time: .departureTime, support: .support} | select(.time == \"$departure_time\") | select(.support == false) | .seats ] | add // 0"
      )";

      echo result: "$n_seats_available";
      test "$n_seats_available" -gt 0 && \
        notify-send \
        --urgency=critical \
        --expire-time=60000 \
        "$n_seats_available seats available" \
        "$n_seats_available seats available for departure at $(date --date=$departure_time), see https://regiojet.cz/?departureDate=$departure_date&tariffs=REGULAR&fromLocationId=$from&fromLocationType=CITY&toLocationId=$to&toLocationType=CITY";
      sleep 60;
    done
  '';
}
