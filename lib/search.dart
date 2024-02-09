import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapSearch extends SearchDelegate {
  final List<Marker> markers; // Pass your markers to the search delegate

  MapSearch(this.markers);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    // Implement your search results here
    return Container(
        // Your search results UI
        );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestionList = markers
        .where(
          (marker) => marker.infoWindow.title!
              .toLowerCase()
              .contains(query.toLowerCase()),
        )
        .toList();

    return ListView.builder(
      itemCount: suggestionList.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(suggestionList[index].infoWindow.title!),
          onTap: () {
            // Handle the tap on a suggestion
            // You may want to navigate to the selected location or perform some action
          },
        );
      },
    );
  }
}
