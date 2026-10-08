def test_health(client):
    assert client.get("/health").json() == {"status": "UP"}


def test_info_reports_version(client):
    body = client.get("/api/info").json()
    assert body["version"] == "1.0.0"
    assert body["hostname"]


def test_ready_checks_database(client):
    r = client.get("/ready")
    assert r.status_code == 200
    assert r.json() == {"status": "READY"}


def test_create_and_get_book(client, book):
    assert book["available_copies"] == 2
    r = client.get(f"/api/books/{book['id']}")
    assert r.status_code == 200
    assert r.json()["title"] == "Site Reliability Engineering"


def test_create_book_validation(client):
    r = client.post("/api/books", json={"title": "", "author": "x", "total_copies": 0})
    assert r.status_code == 422


def test_list_and_filter_by_category(client, book):
    client.post("/api/books", json={"title": "Terraform: Up & Running", "author": "Yevgeniy Brikman", "category": "CLOUD"})
    assert len(client.get("/api/books").json()) == 2
    cloud = client.get("/api/books", params={"category": "cloud"}).json()
    assert [b["title"] for b in cloud] == ["Terraform: Up & Running"]


def test_update_book(client, book):
    r = client.put(f"/api/books/{book['id']}", json={"total_copies": 5})
    assert r.status_code == 200
    assert r.json()["total_copies"] == 5
    assert r.json()["available_copies"] == 5


def test_issue_and_return_rules(client, book):
    url = f"/api/books/{book['id']}"
    assert client.post(f"{url}/issue").json()["available_copies"] == 1
    assert client.post(f"{url}/issue").json()["available_copies"] == 0
    assert client.post(f"{url}/issue").status_code == 409          # nothing left
    assert client.delete(url).status_code == 409                    # cannot delete while issued
    assert client.post(f"{url}/return").json()["available_copies"] == 1


def test_stats(client, book):
    client.post(f"/api/books/{book['id']}/issue")
    assert client.get("/api/books/stats").json() == {
        "titles": 1, "total_copies": 2, "available_copies": 1, "issued_copies": 1}


def test_delete_book_and_404(client, book):
    assert client.delete(f"/api/books/{book['id']}").status_code == 204
    assert client.get(f"/api/books/{book['id']}").status_code == 404


def _issued(client):
    for line in client.get("/metrics").text.splitlines():
        if line.startswith('library_loans_total{action="issue"}'):
            return float(line.split()[-1])
    return 0.0


def test_metrics_endpoint(client, book):
    before = _issued(client)
    client.post(f"/api/books/{book['id']}/issue")
    assert _issued(client) == before + 1
    assert "http_requests_total" in client.get("/metrics").text
