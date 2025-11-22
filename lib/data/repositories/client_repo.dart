import '../models/client.dart';
import '../services/api_client.dart';
import '../services/client_service.dart';

class ClientRepo {
  final ClientService _clientService;

  ClientRepo(ApiClient apiClient) : _clientService = ClientService(apiClient);

  Future<List<Client>> getAll({String? search}) {
    return _clientService.getAll(search: search);
  }

  Future<Client> getById(String id) {
    return _clientService.getById(id);
  }

  Future<Client> create(Client client) {
    return _clientService.create(client);
  }

  Future<Client> update(String id, Client client) {
    return _clientService.update(id, client);
  }

  Future<void> delete(String id) {
    return _clientService.delete(id);
  }
}

